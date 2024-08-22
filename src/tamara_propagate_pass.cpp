// Copyright (c) 2024 Matt Young.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"
#include <functional>
#include <queue>
#include <vector>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

const auto PROPAGATE_ANNOTATION = ID(tamara_triplicate);

/**
 * The tamara_propagate command propagates (* tamara_triplicate *) Verilog annotations throughout the design.
 */
struct TamaraPropagatePass : public Pass {

    TamaraPropagatePass() : Pass("tamara_propagate", "Propagates TaMaRa triplicate annotations") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tamara_propagate\n");
        log("\n");

        log("Propagates (* tamara_triplicate *) annotations through the design hierarchy.\n");
        log("For example, modules marked (* tamara_triplicate *) will have this annotation\n");
        log("applied to all their sub-processes and sub-cells.\n");
        log("This command should be run after 'read_verilog', before 'tamara_triplicate'.\n\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Propagating TaMaRa triplicate annotations\n\n");
        log_push();

        propagateModules(design);

        log_pop();
    }

  private:
    /// Propagate (* tamara_triplicate *) annotations applied to modules to all the module processes and cells
    static void propagateModules(RTLIL::Design *design) {
        for (const auto &module : design->selected_modules()) {
            if (module->has_attribute(PROPAGATE_ANNOTATION)) {
                log("Propagating module '%s'\n", log_id(module->name));

                // processes
                for (const auto &processPair : module->processes) {
                    log("    Visit process '%s'\n", log_id(processPair.second->name));
                    processPair.second->set_bool_attribute(PROPAGATE_ANNOTATION);
                }

                // memories
                // TODO do we want to do this for memories? or do we want to skip memories?
                for (const auto &memoryPair : module->memories) {
                    log("    Visit memory '%s'\n", log_id(memoryPair.second->name));
                    memoryPair.second->set_bool_attribute(PROPAGATE_ANNOTATION);
                }

                // cells
                for (const auto &cell : module->cells()) {
                    log("    Visit cell '%s'\n", log_id(cell->name));
                    cell->set_bool_attribute(PROPAGATE_ANNOTATION);
                }

                // TODO ports: should they have the annotation applied?
            }
        }
    }

    /// Performs a BFS, starting from the cell `cell`, applying the function `visitor`.
    // static void visitCellsBFS(RTLIL::Cell *cell, const std::function<void(RTLIL::Cell *)> &visitor) {
    //     std::queue<RTLIL::Cell *> queue{};
    //     queue.push(cell);
    //
    //     while (!queue.empty()) {
    //         auto *const item = queue.front();
    //         queue.pop();
    //
    //         // apply visitor
    //         visitor(item);
    //
    //         // add children
    //     }
    // }

} const TamaraPropagatePass;

PRIVATE_NAMESPACE_END
