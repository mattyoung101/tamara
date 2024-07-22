#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

/**
 * This is the main TaMaRa TMR command, and so is the main entry point to the TMR process.
 */
struct TamaraTmrPass : public Pass {

    TamaraTmrPass()
        : Pass("tmr", "Starts TaMaRa automated TMR pipeline") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tmr [modules...]\n");
        log("\n");

        log("TaMaRa is an automated Triple Modular Redundancy flow for Yosys.\n\n");

        log("If [modules...] is empty, TaMaRa will apply TMR to all selected modules.\n");
        log("Otherwise, TMR will be applied only to the modules specified.\n\n");

        log("The 'tmr' command should be run after synthesis but before techmapping.\n");
        log("Later, you need to run 'tmr_finalise' to complete the TMR process.\n\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Starting TaMaRa automated Triple Modular Redundancy\n\n");
        log_push();

        std::vector<const RTLIL::Module*> modules;

        if (args.size() <= 1) {
            // use design selected modules
            for (auto *const module : design->selected_modules()) {
                modules.push_back(module);
            }
        } else {
            // lookup modules by args
            // TODO note starting at idx 1
            log_error("Selecting module name by args is not yet supported!\n");
        }

        for (const auto &module : modules) {
            log_push();

            log_header(design, "Applying TMR to module: %s\n", log_id(module->name));
            log("Has processes: %s\n", module->has_processes() ? "yes" : "no");

            log_pop();
        }

        log_pop();
    }

} const TamaraTmrPass;

PRIVATE_NAMESPACE_END
