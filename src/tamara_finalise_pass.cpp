// Copyright (c) 2024 Matt Young.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

/**
 * The tmr_finalise command, used to "unblackbox" the modules that were blackboxed in the tmr command.
 */
struct TamaraFinalisePass : public Pass {

    TamaraFinalisePass() : Pass("tmr_finalise", "Finalises the TaMaRa TMR pipeline") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tmr_finalise\n");
        log("\n");

        log("Finalises the TaMaRa automated TMR process by unpacking blackboxes.\n");
        log("This command should be run after 'tmr'\n\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Finalising TaMaRa automated triple modular redundancy\n\n");
        log_push();

        log_pop();
    }

} const TamaraFinalisePass;

PRIVATE_NAMESPACE_END
