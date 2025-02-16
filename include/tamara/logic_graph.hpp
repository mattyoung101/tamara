// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024-2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/fix_walker.hpp"
#include "tamara/util.hpp"
#include "tamara/voter_builder.hpp"
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <queue>

USING_YOSYS_NAMESPACE;

namespace tamara {

using SigSpecPtr = std::shared_ptr<RTLIL::SigSpec>;

//! Base node class in the graph
class TMRGraphNode : public std::enable_shared_from_this<TMRGraphNode> {
public:
    using Ptr = std::shared_ptr<TMRGraphNode>;

    TMRGraphNode(const TMRGraphNode &) = default;

    TMRGraphNode(TMRGraphNode &&) = delete;

    TMRGraphNode &operator=(const TMRGraphNode &) = default;

    TMRGraphNode &operator=(TMRGraphNode &&) = delete;

    virtual ~TMRGraphNode() = default;

    //! Equality operator for @ref TMRGraphNode::Ptr
    // virtual bool operator==(const TMRGraphNode::Ptr &nodePtr) const = 0;

    //! Constructs a new default TMRGraphNode with the given ID. ID must be monotonically increasing.
    //! Each cone has a unique ID.
    explicit TMRGraphNode(uint32_t id)
        : id(id) {
    }

    /// Returns the ID of the cone this @ref TMRGraphNode belongs to
    [[nodiscard]] uint32_t getConeID() const {
        return id;
    }

    //! Compute neighbours of this node for the backwards BFS
    [[nodiscard]] std::vector<TMRGraphNode::Ptr> computeNeighbours(
        const RTLILWireConnections &connections, const RTLILAnySignalConnections &signalConnections);

    //! Gets a pointer to the underlying RTLIL object
    virtual RTLILAnyPtr getRTLILObjPtr() = 0;

    //! Gets the underlying SigSpecs that may be attached to this node, if relevant
    virtual std::vector<RTLIL::SigSpec> getSigSpecs() = 0;

    //! Replicates the node in the RTLIL netlist
    virtual void replicate(RTLIL::Module *module) = 0;

    //! Identifies this node (for debug)
    virtual std::string identify() = 0;

    //! Returns replicas, if this is supported (not supported on IONode, which cannot be replicated).
    virtual std::vector<RTLILAnyPtr> getReplicas() = 0;

    //! Returns the width of the wire if this makes sense, otherwise throws an error
    virtual int getWidth() = 0;

    //! Hashes this TMRGraphNode instance. Child classes must override.
    virtual size_t hash() const = 0;

    //! Returns a shared ptr to self
    [[nodiscard]] TMRGraphNode::Ptr getSelfPtr() {
        // reference:
        // https://en.cppreference.com/w/cpp/memory/enable_shared_from_this
        // https://stackoverflow.com/questions/11711034/stdshared-ptr-of-this
        return shared_from_this();
    }

private:
    //! ID of the cone that this TMRGraphNode belongs to
    uint32_t id;

    //! During LogicCone::computeNeighbours, this call turns an RTLIL neighbour (ptr) into a new logic graph
    //! node, with the parent correctly set to this TMRGraphNode using getSelfPtr().
    [[nodiscard]] TMRGraphNode::Ptr newLogicGraphNeighbour(
        const RTLILAnyPtr &ptr, const RTLILWireConnections &wireConnections) const;
};

//! Logic element in the graph, between an FFNode and/or an IONode
class ElementCellNode : public TMRGraphNode {
    friend class FFNode;

public:
    explicit ElementCellNode(RTLIL::Cell *cell, uint32_t id)
        : TMRGraphNode(id)
        , cell(cell) {
    }

    ElementCellNode(RTLIL::Cell *cell, const std::vector<RTLIL::SigSpec> &spec, uint32_t id)
        : TMRGraphNode(id)
        , cell(cell) {
        for (const auto &sig : spec) {
            sigSpecs.push_back(sig);
        }
    }

    RTLIL::Cell *getElement() const {
        return cell;
    }

    void replicate(RTLIL::Module *module) override;

    std::string identify() override {
        return "ElementCellNode";
    }

    RTLILAnyPtr getRTLILObjPtr() override {
        return cell;
    }

    std::vector<RTLIL::SigSpec> getSigSpecs() override {
        return sigSpecs;
    }

    std::vector<RTLILAnyPtr> getReplicas() override {
        std::vector<RTLILAnyPtr> out {};
        out.reserve(replicas.size());
        for (const auto &replica : replicas) {
            out.emplace_back(replica);
        }
        return out;
    }

    int getWidth() override {
        log_error("TaMaRa internal error: Cannot get width of an ElementCellNode!\n");
    }

    size_t hash() const override {
        return std::hash<RTLIL::Cell *>()(cell);
        // return std::hash<std::string>()(cell->name.c_str());
    }

private:
    RTLIL::Cell *cell;
    std::vector<RTLIL::SigSpec> sigSpecs;
    std::vector<RTLIL::Cell *> replicas;
};

//! Also a logic element in the graph, but a wire not a cell. See ElementNode.
class ElementWireNode : public TMRGraphNode {
public:
    explicit ElementWireNode(RTLIL::Wire *wire, uint32_t id)
        : TMRGraphNode(id)
        , wire(wire) {
    }

    ElementWireNode(RTLIL::Wire *wire, const std::vector<RTLIL::SigSpec> &spec, uint32_t id)
        : TMRGraphNode(id)
        , wire(wire) {
        for (const auto &sig : spec) {
            sigSpecs.push_back(sig);
        }
    }

    RTLIL::Wire *getWire() const {
        return wire;
    }

    void replicate(RTLIL::Module *module) override;

    std::string identify() override {
        return "ElementWireNode";
    }

    RTLILAnyPtr getRTLILObjPtr() override {
        return wire;
    }

    std::vector<RTLIL::SigSpec> getSigSpecs() override {
        return sigSpecs;
    }

    std::vector<RTLILAnyPtr> getReplicas() override {
        std::vector<RTLILAnyPtr> out {};
        out.reserve(replicas.size());
        for (const auto &replica : replicas) {
            out.emplace_back(replica);
        }
        return out;
    }

    int getWidth() override {
        return wire->width;
    }

    size_t hash() const override {
        return std::hash<RTLIL::Wire *>()(wire);
        // return std::hash<std::string>()(wire->name.c_str());
    }

private:
    RTLIL::Wire *wire;
    std::vector<RTLIL::SigSpec> sigSpecs;
    std::vector<RTLIL::Wire *> replicas;
};

//! Flip flop node in the graph
class FFNode : public ElementCellNode {
    // functionally identical to ElementNode, we just need the class to distinguish from ElementNode
public:
    explicit FFNode(RTLIL::Cell *cell, uint32_t id)
        : ElementCellNode(cell, id) {
    }

    RTLIL::Cell *getFF() {
        return cell;
    }

    std::string identify() override {
        return "FFNode";
    }
};

//! IO port node in the graph. An IONode must be at the end, so it has no neighbours, it's a direct IO to the
//! FPGA/ASIC output.
class IONode : public TMRGraphNode {
public:
    explicit IONode(RTLIL::Wire *io, uint32_t id)
        : TMRGraphNode(id)
        , io(io) {
    }

    IONode(RTLIL::Wire *io, const std::vector<RTLIL::SigSpec> &spec, uint32_t id)
        : TMRGraphNode(id)
        , io(io) {
        for (const auto &sig : spec) {
            sigSpecs.push_back(sig);
        }
    }

    RTLIL::Wire *getIO() {
        return io;
    }

    void replicate(RTLIL::Module *module) override;

    std::string identify() override {
        return "IONode";
    }

    RTLILAnyPtr getRTLILObjPtr() override {
        return io;
    }

    std::vector<RTLIL::SigSpec> getSigSpecs() override {
        return sigSpecs;
    }

    std::vector<RTLILAnyPtr> getReplicas() override {
        log_error("TaMaRa internal error: Cannot get replicas of an IONode!");
    }

    int getWidth() override {
        return io->width;
    }

    size_t hash() const override {
        return std::hash<RTLIL::Wire *>()(io);
        // return std::hash<std::string>()(io->name.c_str());
    }

private:
    RTLIL::Wire *io;
    std::vector<RTLIL::SigSpec> sigSpecs;
};

//! Encapsulates the logic elements between two FFs, or two IO ports, or an IO port and an FF
class LogicCone {
public:
    //! Instantiates a new logic cone from the starting output wire.
    explicit LogicCone(RTLIL::Wire *io)
        : outputNode(std::make_shared<IONode>(io, nextID()))
        , id(outputNode->getConeID()) {
        insertFixWalkers();
    }

    //! Instantiates a new logic cone from the intermediate flip-flop cell.
    LogicCone(RTLIL::Cell *ff)
        : outputNode(std::make_shared<FFNode>(ff, nextID()))
        , id(outputNode->getConeID()) {
        if (!isDFF(ff)) {
            log_error("TaMaRa internal error: Tried to instantiate LogicCone with non-DFF cell '%s'!\n",
                log_id(ff->name));
        }
        insertFixWalkers();
    }

    //! Builds a logic cone by tracing backwards from outputNode to either a DFF or other IO.
    void search(const RTLILWireConnections &connections, const RTLILAnySignalConnections &signalConnections);

    //! Replicates the RTLIL components in a logic cone
    void replicate(RTLIL::Module *module);

    //! Wires up the replicated components and the module, and inserts a voter
    void wire(RTLIL::Module *module, const RTLILWireConnections &connections,
        const RTLILAnySignalConnections &signalConnections, VoterBuilder &builder);

    //! Builds a new logic cone that will continue the search onwards, or none if we're already at the input
    std::vector<LogicCone> buildSuccessors(const RTLILWireConnections &connections);

private:
    /// this is the list of terminals: the list of IO nodes or FF nodes that we end up on through our
    /// backwards ! BFS. when we reach a terminal, we try and finalise the search by not adding any more nodes
    /// from that ! terminal. however, we could still encounter multiple terminals, hence the list.
    std::vector<TMRGraphNode::Ptr> inputNodes;

    /// a cone has only one output (so far)
    TMRGraphNode::Ptr outputNode;

    /// list of logic cone elements, to be replicated (does not include terminals)
    std::vector<TMRGraphNode::Ptr> cone;

    /// voter cut point (i.e. where to wire the voter), this is the first node found on the backwards BFS
    std::optional<TMRGraphNode::Ptr> voterCutPoint;

    /// BFS frontier
    std::queue<TMRGraphNode::Ptr> frontier;

    /// logic cone ID, mostly used to identify this cone for debug
    uint32_t id;

    //! Verifies all terminals in LogicCone::search are legal.
    void verifyInputNodes() const;

    //! From a node under consideration, inserts a voter into the cone.
    //! @param replicas Replicas for this node, should be of length 3 (includes the node itself).
    //! @returns The output wire, or none if no voter was inserted.
    std::optional<RTLIL::Wire *> insertVoter(VoterBuilder &builder, const std::vector<RTLILAnyPtr> &replicas);

    FixWalkerManager fixWalkers;
    // PERF This might be a little non-optimal, should be static
    void insertFixWalkers() {
        fixWalkers.add(std::make_shared<MultiDriverFixer>());
    }

    // Based on this idea: https://stackoverflow.com/a/2978575
    // We don't thread, so no mutex required
    static uint32_t g_cone_ID;
    static uint32_t nextID() {
        return g_cone_ID++;
    }

    /// Contains the names of starting nodes for cones we've already discovered in @ref
    /// LogicCone::buildSuccessors. This is to stop us from infinite looping when we discover new successor
    /// cones.
    static ankerl::unordered_dense::set<std::string> exploredSuccessors;
};

} // namespace tamara

namespace std {

template <>
struct hash<tamara::TMRGraphNode> {
    std::size_t operator()(const tamara::TMRGraphNode &node) const {
        return node.hash();
    }
};

template <>
struct hash<tamara::TMRGraphNode::Ptr> {
    std::size_t operator()(const tamara::TMRGraphNode::Ptr &node) const {
        return node->hash();
    }
};

} // namespace std
