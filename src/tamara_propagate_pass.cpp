// Copyright (c) 2024 Matt Young.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <functional>
#include <queue>
#include <vector>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

const auto TRIPLICATE_ANNOTATION = ID(tamara_triplicate);
const auto IGNORE_ANNOTATION = ID(tamara_ignore);

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
            if (module->has_attribute(TRIPLICATE_ANNOTATION) && shouldPropagate(module)) {
                log("Propagating module '%s'\n", log_id(module->name));

                // processes
                for (const auto &processPair : module->processes) {
                    auto *const process = processPair.second;
                    if (shouldPropagate(process)) {
                        log("    Propagate process '%s'\n", log_id(process->name));
                        process->set_bool_attribute(TRIPLICATE_ANNOTATION);
                    } else {
                        log("    Ignore process '%s'\n", log_id(process->name));
                    }
                }

                // memories
                // TODO do we want to do this for memories? or do we want to skip memories?
                for (const auto &memoryPair : module->memories) {
                    auto *const memory = memoryPair.second;
                    if (shouldPropagate(memory)) {
                        log("    Propagate memory '%s'\n", log_id(memory->name));
                        memory->set_bool_attribute(TRIPLICATE_ANNOTATION);
                    } else {
                        log("    Ignore memory '%s'\n", log_id(memory->name));
                    }
                }

                // cells
                for (const auto &cell : module->cells()) {
                    if (shouldPropagate(cell)) {
                        log("    Propagate cell '%s'\n", log_id(cell->name));
                        cell->set_bool_attribute(TRIPLICATE_ANNOTATION);
                    } else {
                        log("    Ignore cell '%s'\n", log_id(cell->name));
                    }
                }

                // TODO ports: should they have the annotation applied?
            }
        }
    }

    /// Determines if an RTLIL object should be propagated, i.e. it does not have the ignore annotation.
    static constexpr bool shouldPropagate(RTLIL::AttrObject *object) {
        return !object->has_attribute(IGNORE_ANNOTATION);
    }

} const TamaraPropagatePass;

PRIVATE_NAMESPACE_END
