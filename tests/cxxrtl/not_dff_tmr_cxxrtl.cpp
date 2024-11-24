#include <cxxrtl/cxxrtl.h>

#if defined(CXXRTL_INCLUDE_CAPI_IMPL) || defined(CXXRTL_INCLUDE_VCD_CAPI_IMPL)
#include <cxxrtl/capi/cxxrtl_capi.cc>
#endif

#if defined(CXXRTL_INCLUDE_VCD_CAPI_IMPL)
#include <cxxrtl/capi/cxxrtl_capi_vcd.cc>
#endif

using namespace cxxrtl_yosys;

namespace cxxrtl_design {

// \tamara_triplicate: 1
// \top: 1
// \src: ../tests/verilog/not_dff_tmr.sv:5.1-25.10
struct p_not__dff__tmr : public module {
    // \src: ../tests/verilog/not_dff_tmr.sv:13.7-13.9
    // \tamara_cone: 1
    wire<1> i_auto_24_logic__graph_2e_cpp_3a_303_3a_replicate_24__5c_ff____replica1__cone1_____24_6;
    // \src: ../tests/verilog/not_dff_tmr.sv:13.7-13.9
    // \tamara_cone: 1
    wire<1> i_auto_24_logic__graph_2e_cpp_3a_304_3a_replicate_24__5c_ff____replica2__cone1_____24_7;
    // \src: ../tests/verilog/not_dff_tmr.sv:6.17-6.18
    /*input*/ value<1> p_a;
    // \src: ../tests/verilog/not_dff_tmr.sv:7.17-7.20
    /*input*/ value<1> p_clk;
    value<1> prev_p_clk;
    bool posedge_p_clk() const {
        return !prev_p_clk.slice<0>().val() && p_clk.slice<0>().val();
    }
    // \src: ../tests/verilog/not_dff_tmr.sv:10.18-10.21
    // \tamara_error_sink: 1
    /*output*/ value<1> p_err;
    // \src: ../tests/verilog/not_dff_tmr.sv:13.7-13.9
    // \tamara_cone: 1
    // \tamara_original: 1
    wire<1> p_ff;
    // \src: ../tests/verilog/not_dff_tmr.sv:8.18-8.19
    /*output*/ value<1> p_o;
    p_not__dff__tmr(interior) {
    }
    p_not__dff__tmr() {
        reset();
    };

    void reset() override;

    bool eval(performer *performer = nullptr) override;

    template <class ObserverT>
    bool commit(ObserverT &observer) {
        bool changed = false;
        if (i_auto_24_logic__graph_2e_cpp_3a_303_3a_replicate_24__5c_ff____replica1__cone1_____24_6.commit(
                observer))
            changed = true;
        if (i_auto_24_logic__graph_2e_cpp_3a_304_3a_replicate_24__5c_ff____replica2__cone1_____24_7.commit(
                observer))
            changed = true;
        prev_p_clk = p_clk;
        if (p_ff.commit(observer))
            changed = true;
        return changed;
    }

    bool commit() override {
        observer observer;
        return commit<>(observer);
    }

    void debug_eval();

    void debug_info(
        debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs = {}) override;
}; // struct p_not__dff__tmr

void p_not__dff__tmr::reset() {
}

bool p_not__dff__tmr::eval(performer *performer) {
    bool converged = true;
    bool posedge_p_clk = this->posedge_p_clk();
    value<1> i_auto_24_voter__builder_2e_cpp_3a_38_3a_build_24_A_24_10;
    value<1> i_auto_24_voter__builder_2e_cpp_3a_39_3a_build_24_B_24_11;
    value<1> i_auto_24_voter__builder_2e_cpp_3a_40_3a_build_24_C_24_12;
    // \src: ../tests/verilog/not_dff_tmr.sv:19.12-19.15
    // \tamara_cone: 1
    // cell
    // $auto$logic_graph.cpp:276:replicate$$logic_not$../tests/verilog/not_dff_tmr.sv:19$2__replica1_cone1__$4
    i_auto_24_voter__builder_2e_cpp_3a_38_3a_build_24_A_24_10 = logic_not<1>(
        i_auto_24_logic__graph_2e_cpp_3a_303_3a_replicate_24__5c_ff____replica1__cone1_____24_6.curr);
    // \src: ../tests/verilog/not_dff_tmr.sv:19.12-19.15
    // \tamara_cone: 1
    // \tamara_original: 1
    // cell $logic_not$../tests/verilog/not_dff_tmr.sv:19$2
    i_auto_24_voter__builder_2e_cpp_3a_40_3a_build_24_C_24_12 = logic_not<1>(p_ff.curr);
    // \src: ../tests/verilog/not_dff_tmr.sv:19.12-19.15
    // \tamara_cone: 1
    // cell
    // $auto$logic_graph.cpp:277:replicate$$logic_not$../tests/verilog/not_dff_tmr.sv:19$2__replica2_cone1__$5
    i_auto_24_voter__builder_2e_cpp_3a_39_3a_build_24_B_24_11 = logic_not<1>(
        i_auto_24_logic__graph_2e_cpp_3a_304_3a_replicate_24__5c_ff____replica2__cone1_____24_7.curr);
    // \always_ff: 1
    // \src: ../tests/verilog/not_dff_tmr.sv:15.1-17.4
    // \tamara_cone: 1
    // \tamara_original: 1
    // cell $procdff$3
    if (posedge_p_clk) {
        p_ff.next = p_a;
    }
    // \always_ff: 1
    // \src: ../tests/verilog/not_dff_tmr.sv:15.1-17.4
    // \tamara_cone: 1
    // cell $auto$logic_graph.cpp:276:replicate$$procdff$3__replica1_cone1__$8
    if (posedge_p_clk) {
        i_auto_24_logic__graph_2e_cpp_3a_303_3a_replicate_24__5c_ff____replica1__cone1_____24_6.next = p_a;
    }
    // \always_ff: 1
    // \src: ../tests/verilog/not_dff_tmr.sv:15.1-17.4
    // \tamara_cone: 1
    // cell $auto$logic_graph.cpp:277:replicate$$procdff$3__replica2_cone1__$9
    if (posedge_p_clk) {
        i_auto_24_logic__graph_2e_cpp_3a_304_3a_replicate_24__5c_ff____replica2__cone1_____24_7.next = p_a;
    }
    // cells $auto$voter_builder.cpp:99:build$or3$38 $auto$voter_builder.cpp:93:build$or1$36
    // $auto$voter_builder.cpp:72:build$and2$26 $auto$voter_builder.cpp:76:build$and3$28
    // $auto$voter_builder.cpp:84:build$and5$32
    p_err = logic_or<1>(
        logic_or<1>(
            logic_and<1>(
                i_auto_24_logic__graph_2e_cpp_3a_303_3a_replicate_24__5c_ff____replica1__cone1_____24_6.curr,
                i_auto_24_voter__builder_2e_cpp_3a_40_3a_build_24_C_24_12),
            logic_and<1>(
                i_auto_24_logic__graph_2e_cpp_3a_304_3a_replicate_24__5c_ff____replica2__cone1_____24_7.curr,
                i_auto_24_voter__builder_2e_cpp_3a_38_3a_build_24_A_24_10)),
        logic_and<1>(p_ff.curr, i_auto_24_voter__builder_2e_cpp_3a_39_3a_build_24_B_24_11));
    // cells $auto$voter_builder.cpp:96:build$or2$37 $auto$voter_builder.cpp:89:build$or0$34
    // $auto$voter_builder.cpp:64:build$and0$22 $auto$voter_builder.cpp:68:build$and1$24
    // $auto$voter_builder.cpp:80:build$and4$30
    p_o = logic_or<1>(logic_or<1>(logic_and<1>(i_auto_24_voter__builder_2e_cpp_3a_39_3a_build_24_B_24_11,
                                      i_auto_24_voter__builder_2e_cpp_3a_40_3a_build_24_C_24_12),
                          logic_and<1>(i_auto_24_voter__builder_2e_cpp_3a_38_3a_build_24_A_24_10,
                              i_auto_24_voter__builder_2e_cpp_3a_40_3a_build_24_C_24_12)),
        logic_and<1>(i_auto_24_voter__builder_2e_cpp_3a_38_3a_build_24_A_24_10,
            i_auto_24_voter__builder_2e_cpp_3a_39_3a_build_24_B_24_11));
    return converged;
}

void p_not__dff__tmr::debug_eval() {
}

CXXRTL_EXTREMELY_COLD
void p_not__dff__tmr::debug_info(
    debug_items *items, debug_scopes *scopes, std::string path, metadata_map &&cell_attrs) {
    assert(path.empty() || path[path.size() - 1] == ' ');
    if (scopes) {
        scopes->add(path.empty() ? path : path.substr(0, path.size() - 1), "not_dff_tmr",
            metadata_map({
                { "tamara_triplicate", UINT64_C(1) },
                { "top", UINT64_C(1) },
                { "src", "../tests/verilog/not_dff_tmr.sv:5.1-25.10" },
            }),
            std::move(cell_attrs));
    }
    if (items) {
        items->add(path, "a", "src\000s../tests/verilog/not_dff_tmr.sv:6.17-6.18\000", p_a, 0,
            debug_item::INPUT | debug_item::UNDRIVEN);
        items->add(path, "clk", "src\000s../tests/verilog/not_dff_tmr.sv:7.17-7.20\000", p_clk, 0,
            debug_item::INPUT | debug_item::UNDRIVEN);
        items->add(path, "err",
            "src\000s../tests/verilog/"
            "not_dff_tmr.sv:10.18-10.21\000tamara_error_sink\000u\000\000\000\000\000\000\000\001",
            p_err, 0, debug_item::OUTPUT | debug_item::DRIVEN_COMB);
        items->add(path, "ff",
            "src\000s../tests/verilog/"
            "not_dff_tmr.sv:13.7-13.9\000tamara_cone\000s1\000tamara_"
            "original\000u\000\000\000\000\000\000\000\001",
            p_ff, 0, debug_item::DRIVEN_SYNC);
        items->add(path, "o", "src\000s../tests/verilog/not_dff_tmr.sv:8.18-8.19\000", p_o, 0,
            debug_item::OUTPUT | debug_item::DRIVEN_COMB);
    }
}

} // namespace cxxrtl_design

extern "C" cxxrtl_toplevel cxxrtl_design_create() {
    return new _cxxrtl_toplevel { std::unique_ptr<cxxrtl_design::p_not__dff__tmr>(
        new cxxrtl_design::p_not__dff__tmr) };
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <cxxrtl/cxxrtl_vcd.h>
#include <fstream>

// partially based on: https://github.com/tomverbeure/cxxrtl_eval/blob/master/blink_vcd/main.cpp

int main() {
    // cxxrtl_design::p_not__dff__tmr top;
    //
    // // debug_items maps the hierarchical names of signals and memories in the design
    // // to a cxxrtl_object (a value, a wire, or a memory)
    // cxxrtl::debug_items all_debug_items;
    //
    // // Load the debug items of the top down the whole design hierarchy
    // top.debug_info(all_debug_items);
    //
    // // vcd_writer is the CXXRTL object that's responsible of creating a string with
    // // the VCD file contents.
    // cxxrtl::vcd_writer vcd;
    // vcd.timescale(1, "us");
    //
    // // Here we tell the vcd writer to dump all the signals of the design, except for the
    // // memories, to the VCD file.
    // //
    // // It's not necessary to load all debug objects to the VCD. There is, for example,
    // // a  vcd.add(<debug items>, <filter>)) method which allows creating your custom filter to decide
    // // what to add and what not.
    // vcd.add_without_memories(all_debug_items);
    //
    // std::ofstream waves("waves.vcd");
    //
    // top.step();
    // // We need to manually tell the VCD writer when sample and write out the traced items.
    // // This is only a slight inconvenience and allows for complete flexibilty.
    // // E.g. you could only start waveform tracing when an internal signal has reached some specific
    // // value etc.
    // vcd.sample(0);
    //
    // // "a" is always false in the case that produces the error
    // top.p_a.set<bool>(false);
    //
    // // clock on
    // top.p_clk.set<bool>(true);
    // top.step();
    //
    // // clock off
    // top.p_clk.set<bool>(false);
    // top.step();
}
