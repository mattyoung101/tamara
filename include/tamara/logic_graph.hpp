// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/voter_builder.hpp"
#include <optional>
#include <queue>

USING_YOSYS_NAMESPACE;

namespace tamara {

//! Base node class in the graph
class TMRGraphNode {
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

    [[nodiscard]] size_t getConeID() const {
        return id;
    }

    //! Virtual method that sub-classes should override to compute neighbours of this node for BFS
    virtual std::vector<TMRGraphNode::Ptr> computeNeighbours() = 0;

    //! Replicates the node in the RTLIL netlist
    virtual void replicate(RTLIL::Module *module) = 0;

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

    std::vector<TMRGraphNode::Ptr> computeNeighbours() override;

    void replicate(RTLIL::Module *module) override;

private:
    RTLIL::Cell *cell;
};

//! Flip flop node in the graph
class FFNode : public ElementNode {
    // functionally identical to ElementNode, we just need the class to distinguish from ElementNode
public:
    RTLIL::Cell *getFF() {
        return cell;
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

    std::vector<TMRGraphNode::Ptr> computeNeighbours() override;

    void replicate(RTLIL::Module *module) override;

private:
    RTLIL::Wire *io;
};

//! Encapsulates the logic elements between two FFs, or two IO ports, or an IO port and an FF
class LogicCone {
public:
    //! Instantiates a new logic cone with the ID. ID must be unique and monotonically increasing.
    LogicCone(uint32_t id)
        : id(id) {
    }

    //! Builds a logic cone by tracing backwards from an output IO to either a DFF or other IO.
    void search(RTLIL::Module *module, RTLIL::Wire *output);

    //! Replicates the RTLIL components in a logic cone
    void replicate(RTLIL::Module *module);

    //! Inserts voters into the module
    void insertVoter(RTLIL::Module *module);

    //! Wires up the replicated components and the module
    void wire(RTLIL::Module *module);

    //! Builds a new logic cone that will continue the search onwards, or none if we're already at the input
    std::optional<LogicCone> buildSuccessor();

private:
    TMRGraphNode::Ptr inputNode;
    TMRGraphNode::Ptr outputNode;
    std::vector<TMRGraphNode::Ptr> cone; // list of logic cone elements, to be replicated (does not include
    // terminals)
    std::queue<TMRGraphNode::Ptr> frontier; // BFS frontier
    std::optional<Voter> voter; // logic cone voter, if it's been inserted
    uint32_t id; // logic cone ID
};

} // namespace tamara
