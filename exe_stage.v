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

    //div_mul
    output wire                         es_div_enable              ,
    output wire                         es_mul_enable              ,//之前没加入mul en 仿真时间非常长, 
    output wire                         es_mul_div_sign            ,
    output wire        [  31:0]         rj_value                   ,
    output wire        [  31:0]         rkd_value                  ,
    input  wire                         div_complete               ,


//用于前递 forward
    output wire        [   4:0]         ex_dest                    ,//输出给id 目前用于阻塞
    output wire        [  31:0]         es_to_ds_result            ,//前递计算后的数据
    output wire                         es_to_ds_load_op           ,//前递 当前阶段是否为load指令
    output wire                         div_stall                  ,//目前可能暂时不需要输出,直接在本周期本阶段阻塞即可

// data sram interface(write) 
    output wire                         data_sram_en               ,//对sram的接口 
    output wire        [   3:0]         data_sram_we               ,
    output wire        [  31:0]         data_sram_addr             ,
    output wire        [  31:0]         data_sram_wdata             
    // output  wire      es_to_ds_load_op
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
// wire [31:0] rj_value;
// wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] es_pc;
wire [1:0] es_mem_size;
// wire div_stall;//除法器阻塞
// wire es_div_enable;
// wire es_mul_enable;
wire [ 3:0] es_mul_div_op;
wire es_mem_sign_exted ;


assign {
        es_mem_sign_exted, //159:159   是否符号拓展
        es_mem_size ,      // 158:157  ld类指令访存大小 01 - b  11 - h
        es_mul_div_op   ,   // 156:153   乘除op
        es_mul_div_sign ,   // 152:152   有符号乘除法
        alu_op,      
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


assign es_to_ms_bus = {
                        es_mem_sign_exted, //77:77   是否符号拓展
                        es_mem_size,   //76:75 2
                        es_mul_div_op, //74:71 4    
                        res_from_mem,  //70:70 1
                       gr_we       ,  //69:69 1
                       dest        ,  //68:64 5
                       alu_result  ,  //63:32 32
                       es_pc          //31:0  32
                      };


assign es_ready_go    = ~ div_stall;
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


assign es_div_enable = (es_mul_div_op[2] | es_mul_div_op[3]) & es_valid;
assign es_mul_enable = (es_mul_div_op[0] | es_mul_div_op[1] ) & es_valid ;

assign div_stall = es_div_enable & ~div_complete;//除法阻塞

//前递 to ds  两个数据都是在本阶段的上升沿后 触发ds_to_es_bus_r中的数据更新 再使用组合逻辑执行es阶段
assign ex_dest = dest & {5{es_valid}};
assign es_to_ds_result = alu_result;


wire [ 1:0] sram_addr_low2bit;
assign sram_addr_low2bit = {alu_result[1], alu_result[0]};

wire [3:0] es_stb_wen = { sram_addr_low2bit==2'b11  ,
                          sram_addr_low2bit==2'b10  ,
                          sram_addr_low2bit==2'b01  ,
                          sram_addr_low2bit==2'b00} ;

wire [3:0] es_sth_wen = { sram_addr_low2bit==2'b10  ,
                          sram_addr_low2bit==2'b10  ,
                          sram_addr_low2bit==2'b00  ,
                          sram_addr_low2bit==2'b00} ;

wire [31:0] es_stb_cont = { {8{es_stb_wen[3]}} & rkd_value[7:0] ,
                            {8{es_stb_wen[2]}} & rkd_value[7:0] ,
                            {8{es_stb_wen[1]}} & rkd_value[7:0] ,
                            {8{es_stb_wen[0]}} & rkd_value[7:0]};

wire [31:0] es_sth_cont = { {16{es_sth_wen[3]}} & rkd_value[15:0] ,
                            {16{es_sth_wen[0]}} & rkd_value[15:0]};
wire [3:0] wr_byte_en;
wire [2:0] data_size;
assign {wr_byte_en, data_size}  = ({7{es_mem_size[0]}} & {es_stb_wen, 3'b00}) |
                                  ({7{es_mem_size[1]}} & {es_sth_wen, 3'b01}) |
                                  ({7{!es_mem_size  }} & {4'b1111   , 3'b10}) ;        
wire [31:0] data_wdata;
assign data_wdata = ({32{es_mem_size[0]}} & es_stb_cont ) |
                    ({32{es_mem_size[1]}} & es_sth_cont ) |
                    ({32{!es_mem_size  }} & rkd_value) ; 

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = 1'b1;
assign data_sram_we    = es_mem_we && es_valid ? wr_byte_en : 4'h0;//
assign data_sram_addr  = alu_result;
assign data_sram_wdata = data_wdata;


endmodule
