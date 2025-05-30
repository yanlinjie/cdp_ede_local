`include "C:/Users/14861/Desktop/loongson/cdp_ede_local/mycpu_env/myCPU/my_cpu.vh"


module if_stage(
    input  wire                         clk                        ,
    input  wire                         reset                      ,
    //allwoin
    input  wire                         ds_allowin                 ,//相当于下游信号的ready
    //brbus
    input  wire        [`BR_BUS_WD       -1:0]br_bus                     ,//跳转信号的前递 from ds
    //to ds
    output wire                         fs_to_ds_valid             ,//相当于fs vaid
    output wire        [`FS_TO_DS_BUS_WD -1:0]fs_to_ds_bus               ,//传给下游ds的数据
    // inst sram interface
    output wire                         inst_sram_en               ,//外设接口 用于取值
    output wire        [   3:0]         inst_sram_we               ,
    output wire        [  31:0]         inst_sram_addr             ,
    output wire        [  31:0]         inst_sram_wdata            ,
    input  wire        [  31:0]         inst_sram_rdata             
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_stall, br_taken, br_target} = br_bus;
// pre-IF stage
assign to_fs_valid  = ~reset && pre_if_ready_go;
assign pre_if_ready_go = ~br_stall;
// if taken is valid and if stage is block, get the instruction after the jump inst


wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset;
// because after sending fs_pc to ds, the seq_pc = fs_pc + 4 immediately
// Actually, the seq_pc is just a delay slot instruction
// if we use inst pc, here need to -4, it's more troublesome
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc; 

// IF stage
assign fs_ready_go    = ~ br_taken;   // 准备发送
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;     // (!fs_valid) || (fs_ready_go && ds_allowin);

assign fs_to_ds_valid =  fs_valid && fs_ready_go; //当前时钟周期取值到译码的数据有效 即：
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    //目前复位后，fs基本上一直有效
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && (fs_allowin || br_taken)) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && (fs_allowin || br_taken) && pre_if_ready_go;
assign inst_sram_we   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

endmodule
