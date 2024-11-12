// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"
#include "tamara/voter_builder.hpp"
#include <cstdint>
#include <optional>
#include <queue>
#include <stdexcept>

USING_YOSYS_NAMESPACE;

// FIXME I think we should remove all the parents stuff, it isn't necessary any more and doesn't make sense I
// think

namespace tamara {

//! Base node class in the graph
class TMRGraphNode : public std::enable_shared_from_this<TMRGraphNode> {
public:
    using Ptr = std::shared_ptr<TMRGraphNode>;

    TMRGraphNode(const TMRGraphNode &) = default;

    TMRGraphNode(TMRGraphNode &&) = delete;

    TMRGraphNode &operator=(const TMRGraphNode &) = default;

    TMRGraphNode &operator=(TMRGraphNode &&) = delete;

    virtual ~TMRGraphNode() = default;

    //! Constructs a new default TMRGraphNode with the given ID. ID must be monotonically increasing.
    //! Each cone has a unique ID.
    explicit TMRGraphNode(uint32_t id)
        : id(id) {
    }

    TMRGraphNode(const TMRGraphNode::Ptr &parent, uint32_t id)
        : parent(parent)
        , id(id) {
    }

    [[nodiscard]] std::optional<TMRGraphNode::Ptr> getParent() {
        return parent;
    }

    [[nodiscard]] uint32_t getConeID() const {
        return id;
    }

    //! Compute neighbours of this node for the backwards BFS
    [[nodiscard]] std::vector<TMRGraphNode::Ptr> computeNeighbours(
        RTLIL::Module *module, RTLILWireConnections &connections);

    //! Gets a pointer to the underlying RTLIL object
    virtual RTLILAnyPtr getRTLILObjPtr() = 0;

    //! Replicates the node in the RTLIL netlist
    virtual void replicate(RTLIL::Module *module) = 0;

    //! Identifies this node (for debug)
    virtual std::string identify() = 0;

    //! Returns replicas, if this is supported (not supported on IONode, which cannot be replicated).
    virtual std::vector<RTLILAnyPtr> getReplicas() = 0;

    //! During LogicCone::computeNeighbours, this call turns an RTLIL neighbour (ptr) into a new logic graph
    //! node, with the parent correctly set to this TMRGraphNode using getSelfPtr().
    [[nodiscard]] TMRGraphNode::Ptr newLogicGraphNeighbour(
        const RTLILAnyPtr &ptr, RTLILWireConnections &connections);

    //! Returns a shared ptr to self
    [[nodiscard]] TMRGraphNode::Ptr getSelfPtr() {
        // reference:
        // https://en.cppreference.com/w/cpp/memory/enable_shared_from_this
        // https://stackoverflow.com/questions/11711034/stdshared-ptr-of-this
        return shared_from_this();
    }

private:
    //! Pointer to parent node, not present if root
    std::optional<TMRGraphNode::Ptr> parent;

    //! ID of the cone that this TMRGraphNode belongs to
    uint32_t id;
};

//! Logic element in the graph, between an FFNode and/or an IONode
class ElementCellNode : public TMRGraphNode {
    friend class FFNode;

public:
    explicit ElementCellNode(RTLIL::Cell *cell, uint32_t id)
        : TMRGraphNode(id)
        , cell(cell) {
    }

    ElementCellNode(RTLIL::Cell *cell, const TMRGraphNode::Ptr &parent, uint32_t id)
        : TMRGraphNode(parent, id)
        , cell(cell) {
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

    std::vector<RTLILAnyPtr> getReplicas() override {
        std::vector<RTLILAnyPtr> out {};
        out.reserve(replicas.size());
        for (const auto &replica : replicas) {
            out.emplace_back(replica);
        }
        return out;
    }

private:
    RTLIL::Cell *cell;
    std::vector<RTLIL::Cell *> replicas;
};

//! Also a logic element in the graph, but a wire not a cell. See ElementNode.
class ElementWireNode : public TMRGraphNode {
public:
    explicit ElementWireNode(RTLIL::Wire *wire, uint32_t id)
        : TMRGraphNode(id)
        , wire(wire) {
    }

    ElementWireNode(RTLIL::Wire *wire, const TMRGraphNode::Ptr &parent, uint32_t id)
        : TMRGraphNode(parent, id)
        , wire(wire) {
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

    std::vector<RTLILAnyPtr> getReplicas() override {
        std::vector<RTLILAnyPtr> out {};
        out.reserve(replicas.size());
        for (const auto &replica : replicas) {
            out.emplace_back(replica);
        }
        return out;
    }

private:
    RTLIL::Wire *wire;
    std::vector<RTLIL::Wire *> replicas;
};

//! Flip flop node in the graph
class FFNode : public ElementCellNode {
    // functionally identical to ElementNode, we just need the class to distinguish from ElementNode
public:
    explicit FFNode(RTLIL::Cell *cell, uint32_t id)
        : ElementCellNode(cell, id) {
    }

    FFNode(RTLIL::Cell *cell, const TMRGraphNode::Ptr &parent, uint32_t id)
        : ElementCellNode(cell, parent, id) {
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

    IONode(RTLIL::Wire *io, const TMRGraphNode::Ptr &parent, uint32_t id)
        : TMRGraphNode(parent, id)
        , io(io) {
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

    std::vector<RTLILAnyPtr> getReplicas() override {
        log_error("TaMaRa internal error: Cannot get replicas of an IONode!");
    }

private:
    RTLIL::Wire *io;
};

//! Encapsulates the logic elements between two FFs, or two IO ports, or an IO port and an FF
class LogicCone {
public:
    //! Instantiates a new logic cone from the starting output wire.
    explicit LogicCone(RTLIL::Wire *io)
        : outputNode(std::make_shared<IONode>(io, nextID()))
        , id(outputNode->getConeID()) {
    }

    // FIXME check that cell really is a FF when we instantiate
    LogicCone(RTLIL::Cell *ff)
        : outputNode(std::make_shared<FFNode>(ff, nextID()))
        , id(outputNode->getConeID()) {
    }

    //! Builds a logic cone by tracing backwards from outputNode to either a DFF or other IO.
    void search(RTLIL::Module *module, RTLILWireConnections &connections);

    //! Replicates the RTLIL components in a logic cone
    void replicate(RTLIL::Module *module);

    //! Inserts voters into the module
    void insertVoter(RTLIL::Module *module);

    //! Wires up the replicated components and the module
    void wire(RTLIL::Module *module);

    //! Builds a new logic cone that will continue the search onwards, or none if we're already at the input
    std::vector<LogicCone> buildSuccessors(RTLILWireConnections &connections);

private:
    // this is the list of terminals: the list of IO nodes or FF nodes that we end up on through our backwards
    // BFS. when we reach a terminal, we try and finalise the search by not adding any more nodes from that
    // terminal. however, we could still encounter multiple terminals, hence the list.
    std::vector<TMRGraphNode::Ptr> inputNodes;

    // a cone has only one output (so far)
    TMRGraphNode::Ptr outputNode;

    // list of logic cone elements, to be replicated (does not include terminals)
    std::vector<TMRGraphNode::Ptr> cone;

    // voter cut point (i.e. where to wire the voter), this is the first node found on the backwards BFS
    std::optional<TMRGraphNode::Ptr> voterCutPoint;

    // BFS frontier
    std::queue<TMRGraphNode::Ptr> frontier;

    // voter for this logic cone, if it's been inserted
    std::optional<Voter> voter;

    // logic cone ID, mostly used to identify this cone for debug
    uint32_t id;

    void verifyInputNodes() const;

    // Based on this idea: https://stackoverflow.com/a/2978575
    // We don't thread, so no mutex required
    static uint32_t g_cone_ID;
    static uint32_t nextID() {
        return g_cone_ID++;
    }
};

} // namespace tamara
