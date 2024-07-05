#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

/**
 * This is the main TaMaRa TMR entrypoint
 */
struct TamaraTmrPass : public Pass {

    TamaraTmrPass()
        : Pass("tmr", "Starts the TaMaRa automated TMR process") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tmr\n");
        log("\n");

        log("TaMaRa is an automated Triple Modular Redundancy flow for Yosys.\n\n");

        log("The 'tmr' command starts the TMR process on all selected modules, and\n");
        log("should be run after synthesis but before techmapping.\n\n");

        log("Later, you need to run 'tmr_finalise' to complete the TMR process.\n");
        log("\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Starting TaMaRa automated Triple Modular Redundancy\n\n");
        log_push();

        for (const auto &module : design->selected_modules()) {
            log_push();

            log_header(design, "Applying TMR to module: %s\n", log_id(module->name));
            log("Has processes: %s\n", module->has_processes() ? "yes" : "no");

            log_pop();
        }

        log_pop();
    }

} const TamaraTmrPass;

PRIVATE_NAMESPACE_END
