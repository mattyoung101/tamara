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
#include <optional>
#include <queue>
#include <unordered_set>

USING_YOSYS_NAMESPACE;

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

    std::optional<TMRGraphNode::Ptr> getParent() {
        return parent;
    }

    const std::vector<TMRGraphNode::Ptr> &getChildren() {
        return children;
    }

    void addChild(const TMRGraphNode::Ptr &child) {
        children.push_back(child);
    }

    [[nodiscard]] uint32_t getConeID() const {
        return id;
    }

    //! Virtual method that sub-classes should override to compute neighbours of this node for BFS
    std::vector<TMRGraphNode::Ptr> computeNeighbours(RTLIL::Module *module, RTLILWireConnections &connections);

    //! Gets a pointer to the underlying RTLIL object
    virtual RTLILAnyPtr getRTLILObjPtr() = 0;

    //! Replicates the node in the RTLIL netlist
    virtual void replicate(RTLIL::Module *module) = 0;

    //! Identifies this node (for debug)
    virtual std::string identify() = 0;

    //! Converts an RTLILAnyPtr to a TMR graph object. Implementation is cursed, beware. Probably leaks
    //! memory too, but so does upstream so w/e.
    [[nodiscard]] TMRGraphNode::Ptr yosysToLogicGraph(const RTLILAnyPtr &ptr);

    //! Returns a shared ptr to self
    [[nodiscard]] TMRGraphNode::Ptr getSelfPtr() {
        // reference:
        // https://en.cppreference.com/w/cpp/memory/enable_shared_from_this
        // https://stackoverflow.com/questions/11711034/stdshared-ptr-of-this
        return shared_from_this();
    }

private:
    std::optional<TMRGraphNode::Ptr> parent;
    std::vector<TMRGraphNode::Ptr> children;
    uint32_t id;
};

//! Logic element in the graph, between an FFNode and/or an IONode
class ElementNode : public TMRGraphNode {
    friend class FFNode;

public:
    explicit ElementNode(RTLIL::Cell *cell, uint32_t id)
        : TMRGraphNode(id)
        , cell(cell) {
    }

    ElementNode(RTLIL::Cell *cell, const TMRGraphNode::Ptr &parent, uint32_t id)
        : TMRGraphNode(parent, id)
        , cell(cell) {
    }

    RTLIL::Cell *getElement() {
        return cell;
    }

    void replicate(RTLIL::Module *module) override;

    std::string identify() override {
        return "ElementNode";
    }

    RTLILAnyPtr getRTLILObjPtr() override {
        return cell;
    }

private:
    // FIXME This should actually be RTLILAnyPtr, because ElementNodes could be wires or cells
    // not_dff_tmr.ys gives a good example of this
    RTLIL::Cell *cell;
    std::vector<RTLIL::Cell*> replicas;
};

//! Flip flop node in the graph
class FFNode : public ElementNode {
    // functionally identical to ElementNode, we just need the class to distinguish from ElementNode
public:
    explicit FFNode(RTLIL::Cell *cell, uint32_t id)
        : ElementNode(cell, id) {
    }

    FFNode(RTLIL::Cell *cell, const TMRGraphNode::Ptr &parent, uint32_t id)
        : ElementNode(cell, parent, id) {
    }

    RTLIL::Cell *getFF() {
        return cell;
    }

    std::string identify() override {
        return "FFNode";
    }
};

//! IO port node in the graph
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

private:
    RTLIL::Wire *io;
};

//! Encapsulates the logic elements between two FFs, or two IO ports, or an IO port and an FF
class LogicCone {
public:
    //! Instantiates a new logic cone from the starting output wire.
    explicit LogicCone(RTLIL::Wire *io)
        : outputNode(std::make_shared<IONode>(io, nextID())), id(outputNode->getConeID()) {
    }

    // FIXME check that cell really is a FF when we instantiate
    LogicCone(RTLIL::Cell *ff)
        : outputNode(std::make_shared<FFNode>(ff, nextID())), id(outputNode->getConeID()) {
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
