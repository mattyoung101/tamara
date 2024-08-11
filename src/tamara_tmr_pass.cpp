// Copyright (c) 2024 Matt Young.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

/**
 * This is the main TaMaRa TMR command, which starts the TMR process.
 */
struct TamaraTmrPass : public Pass {

    TamaraTmrPass() : Pass("tmr", "Starts TaMaRa automated TMR pipeline") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tmr\n");
        log("\n");

        log("TaMaRa is an automated triple modular redundancy flow for Yosys.\n");
        log("The 'tmr' command will process all the selected modules in the design,\n");
        log("and apply TMR to each one.\n\n");

        log("The 'tmr' command should be run after synthesis but before techmapping.\n");
        log("Later, you must run 'tmr_finalise' to complete the TMR process.\n\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Starting TaMaRa automated triple modular redundancy\n\n");
        log_push();

        // process each selected module from the design
        for (auto *const module : design->selected_modules()) {
            log_push();

            log_header(design, "Applying TMR to module: %s\n", log_id(module->name));
            log("Has processes: %s\n", module->has_processes() ? "yes" : "no");

            log_pop();
        }

        log_pop();
    }

} const TamaraTmrPass;

PRIVATE_NAMESPACE_END
