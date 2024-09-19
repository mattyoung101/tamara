// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <optional>
#include <queue>

USING_YOSYS_NAMESPACE;

namespace tamara {

//! Base node class in the graph
class TMRGraphNode {
public:
    using Ptr = std::shared_ptr<TMRGraphNode>;

    explicit TMRGraphNode() = default;

    TMRGraphNode(const TMRGraphNode &) = default;

    TMRGraphNode(TMRGraphNode &&) = delete;

    TMRGraphNode &operator=(const TMRGraphNode &) = default;

    TMRGraphNode &operator=(TMRGraphNode &&) = delete;

    virtual ~TMRGraphNode() = default;

    TMRGraphNode(const TMRGraphNode::Ptr &parent)
        : parent(parent) {
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

    //! Virtual method that sub-classes should override to compute neighbours of this node for BFS
    virtual const std::vector<TMRGraphNode::Ptr> &computeNeighbours();

private:
    std::optional<TMRGraphNode::Ptr> parent;
    std::vector<TMRGraphNode::Ptr> children;
};

//! Logic element in the graph, between an FFNode and/or an IONode
class ElementNode : public TMRGraphNode {
public:
    explicit ElementNode(RTLIL::Cell *cell)
        : cell(cell) {
    }

    ElementNode(RTLIL::Cell *cell, const TMRGraphNode::Ptr &parent)
        : TMRGraphNode(parent)
        , cell(cell) {
    }

    RTLIL::Cell *getElement() {
        return cell;
    }

    const std::vector<TMRGraphNode::Ptr> &computeNeighbours() override;

private:
    RTLIL::Cell *cell;
};

//! Flip flop node in the graph
class FFNode : public TMRGraphNode {
public:
    explicit FFNode(RTLIL::Cell *ff)
        : ff(ff) {
    }

    FFNode(RTLIL::Cell *ff, const TMRGraphNode::Ptr &parent)
        : TMRGraphNode(parent)
        , ff(ff) {
    }

    RTLIL::Cell *getFF() {
        return ff;
    }

    const std::vector<TMRGraphNode::Ptr> &computeNeighbours() override;

private:
    RTLIL::Cell *ff;
};

//! IO port node in the graph
class IONode : public TMRGraphNode {
public:
    explicit IONode(RTLIL::Wire *io)
        : io(io) {
    }

    IONode(RTLIL::Wire *io, const TMRGraphNode::Ptr &parent)
        : TMRGraphNode(parent)
        , io(io) {
    }

    RTLIL::Wire *getIO() {
        return io;
    }

    const std::vector<TMRGraphNode::Ptr> &computeNeighbours() override;

private:
    RTLIL::Wire *io;
};

//! Encapsulates the logic elements between two FFs, or two IO ports, or an IO port and an FF
class LogicCone {
public:
    LogicCone() = default;

    //! Builds a logic cone by tracing backwards from an output IO to either a DFF or other IO.
    void search(RTLIL::Module *module, RTLIL::Wire *output);

    //! Replicates the RTLIL components in a logic cone
    void replicate(RTLIL::Module *module);

    //! Inserts voters into the module
    void insertVoters(RTLIL::Module *module);

    //! Wires up the replicated components and the module
    void wire(RTLIL::Module *module);

    //! Builds a new logic cone that will continue the search onwards, or none if we're already at the input
    std::optional<LogicCone> buildSuccessor();

private:
    TMRGraphNode::Ptr inputNode;
    TMRGraphNode::Ptr outputNode;
    std::vector<TMRGraphNode::Ptr> cone; // list of logic cone elements, to be replicated
    std::queue<TMRGraphNode::Ptr> frontier; // BFS frontier
};

} // namespace tamara
