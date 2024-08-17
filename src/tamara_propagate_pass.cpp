// Copyright (c) 2024 Matt Young.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

/**
 * The tamara_propagate command propagates (* triplicate *) Verilog annotations throughout the design.
 */
struct TamaraPropagatePass : public Pass {

    TamaraPropagatePass() : Pass("tamara_propagate", "Propagates TaMaRa triplicate annotations") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tamara_propagate\n");
        log("\n");

        log("Finalises the TaMaRa automated TMR process by unpacking blackboxes.\n");
        log("This command should be run after 'tmr'\n\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Propagating TaMaRa triplicate annotations\n\n");
        log_push();

        log_pop();
    }

} const TamaraPropagatePass;

PRIVATE_NAMESPACE_END
