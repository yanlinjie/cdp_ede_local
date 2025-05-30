`include "C:/Users/14861/Desktop/loongson/cdp_ede_local/mycpu_env/myCPU/my_cpu.vh"

module exe_stage(
    input    wire                      clk           ,
    input    wire                      reset         ,
    //allowin
    input   wire                       ms_allowin    ,//下游的allowin
    output  wire                       es_allowin    ,//
    //from ds
    input  wire                        ds_to_es_valid,
    input wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,//来自ds的bus_data
    //to ms
    output  wire                       es_to_ms_valid,//
    output wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus ,//

    output wire [4:0] ex_dest,//输出给id 目前用于阻塞

    // data sram interface(write) 如果需要读出数据，则这个时钟周期就需要使能bram
    output wire       data_sram_en   ,//对sram的接口 
    output wire [ 3:0] data_sram_we   ,
    output wire [31:0] data_sram_addr ,
    output wire [31:0] data_sram_wdata,
    output  wire      es_to_ds_load_op
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [11:0] alu_op      ;
wire        es_load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        es_mem_we;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] es_pc;


assign {alu_op,      
        es_load_op,
        src1_is_pc,
        src2_is_imm, 
        src2_is_4,
        gr_we,
        es_mem_we,
        dest,
        imm,
        rj_value,
        rkd_value,
        es_pc,
        res_from_mem 
       } = ds_to_es_bus_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;


// did't use in lab7
// wire        es_res_from_mem;
// assign es_res_from_mem = es_load_op;
assign es_to_ds_load_op = es_load_op & es_valid;


assign es_to_ms_bus = {res_from_mem,  //70:70 1
                       gr_we       ,  //69:69 1
                       dest        ,  //68:64 5
                       alu_result  ,  //63:32 32
                       es_pc          //31:0  32
                      };

assign ex_dest = dest & {5{es_valid}};

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign alu_src1 = src1_is_pc  ? es_pc  : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = 1'b1;
assign data_sram_we    = es_mem_we && es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;


endmodule
