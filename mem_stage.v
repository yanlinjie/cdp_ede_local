`include "C:/Users/14861/Desktop/loongson/cdp_ede_local/mycpu_env/myCPU/my_cpu.vh"


module mem_stage(
    input    wire                      clk           ,
    input     wire                     reset         ,
    //allowin
    input     wire                     ws_allowin    ,
    output    wire                     ms_allowin    ,
    //from es
    input     wire                     es_to_ms_valid,
    input wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output    wire                     ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,

//用于前递   后续可以合并 减少端口 方便阅读吧
    output wire [4:0] mem_dest,
    output wire [31:0]  ms_to_ds_result,

    //from data-sram
    input wire  [31                 :0] data_sram_rdata,//访存结果
    
input wire [31:0]  div_result,
input wire [31:0]  mod_result,
input wire [63:0]  mul_result
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire [ 3:0] ms_mul_div_op;

assign {
        ms_mul_div_op,
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  = es_to_ms_bus;
    end
end

assign mem_result   = data_sram_rdata;//访存读出的数据
assign ms_final_result = ms_res_from_mem  ?  mem_result        : 
                         ms_mul_div_op[0] ?  mul_result[31:0]  : 
                         ms_mul_div_op[1] ?  mul_result[63:32] :
                         ms_mul_div_op[2] ?  div_result        :
                         ms_mul_div_op[3] ?  mod_result        :   ms_alu_result;

//前递 to ds
assign mem_dest = ms_dest & {5{ms_valid}};//
assign ms_to_ds_result = ms_final_result;

endmodule
