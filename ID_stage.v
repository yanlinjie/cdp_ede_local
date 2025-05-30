`include "C:/Users/14861/Desktop/loongson/cdp_ede_local/mycpu_env/myCPU/my_cpu.vh"
//本阶段译码，如果有跳转指令, 输出跳转数据, 并且前递给上游信号
//输出bus_data给下游
//来自下游的ready 
module id_stage(
    input    wire                      clk           ,
    input     wire                     reset         ,
    //allowin
    input     wire                     es_allowin    ,//相当于下游ready
    output    wire                     ds_allowin    ,//相当于本模块ready to 上游 fs
    //from fs
    input     wire                     fs_to_ds_valid,//上游的valid信号
    input wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,//上游fs数据信号(inst  pc)
    //to es
    output  wire                       ds_to_es_valid,//输出给下游valid 
    output wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus ,//id bus -> es
    //to fs
    output wire [`BR_BUS_WD       -1:0] br_bus       ,//跳转 前递 br_taken br_target
    //to rf: for write back
    input wire  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus , //写回 id模块中有regfile模块

    input wire [4:0] es_to_ds_dest,
    input wire [4:0] ws_to_ds_dest,
    input wire [4:0] ms_to_ds_dest,

    input wire es_to_ds_load_op//用于判断 转移计算未完成  ld + branch的情况

);

wire        br_taken;
wire [31:0] br_target;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

reg         ds_valid   ;
wire        ds_ready_go;

wire [11:0] alu_op;

wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire        src_reg_is_rj;
wire        src_reg_is_rk;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;
wire [31:0] final_result;

wire inst_no_dest;
wire src_no_rj;
wire src_no_rk;
wire src_no_rd;
wire rj_wait;
wire rk_wait;
wire rd_wait;
wire no_wait;
wire br_stall;
wire load_stall;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];//
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];


assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};//inst: bl

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? rk                         :
            /*need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                              {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};


assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;//rd 写使能
assign mem_we        = inst_st_w;
assign dest          = inst_no_dest ? 5'b0 :
                                        dst_is_r1 ? 5'd1 : rd;

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
assign src_reg_is_rj = ~(inst_b | inst_bl | inst_lu12i_w);
assign src_reg_is_rk = ~(inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | 
                      inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w);

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);





// taken signal need to be block too!!!!
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                )  && ds_valid & no_wait;
                
assign inst_no_dest = inst_st_w | inst_b | inst_beq | inst_bne;

assign src_no_rj    = inst_b | inst_bl | inst_lu12i_w;
assign src_no_rk    = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | 
                      inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w;
assign src_no_rd    = ~inst_st_w & ~inst_beq & ~inst_bne;

assign rj_wait = ~src_no_rj && (rj != 5'b00000) && ((rj == es_to_ds_dest) || (rj == ms_to_ds_dest) || (rj == ws_to_ds_dest));
assign rk_wait = ~src_no_rk && (rk != 5'b00000) && ((rk == es_to_ds_dest) || (rk == ms_to_ds_dest) || (rk == ws_to_ds_dest));
assign rd_wait = ~src_no_rd && (rd != 5'b00000) && ((rd == es_to_ds_dest) || (rd == ms_to_ds_dest) || (rd == ws_to_ds_dest));

assign no_wait = ~rj_wait & ~rk_wait & ~rd_wait;


// es is load and ds is jmp(taken)
assign br_stall   = load_stall & br_taken & ds_valid;
assign load_stall = es_to_ds_load_op & (((rj == es_to_ds_dest) & rj_wait) |
                                        ((rk == es_to_ds_dest) & rk_wait) |
                                        ((rd == es_to_ds_dest) & rd_wait)); 
assign br_bus       = {br_stall,br_taken,br_target};


reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

assign load_op  = inst_ld_w;

assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

//译码结束后打包进bus 再传输给下一阶段 
assign ds_to_es_bus = {alu_op       ,   // 12 用于判断alu操作符
                       load_op      ,   // 1  load operator
                       src1_is_pc   ,   // 1  alusrc1来源
                       src2_is_imm  ,   // 1  alusrc2来源
                       src2_is_4    ,   // 1  alusrc2来源 表示是 4
                       gr_we        ,   // 1  rd写使能
                       mem_we       ,   // 1  mem写使能
                       dest         ,   // 5  rd addr
                       imm          ,   // 32 imm
                       rj_value     ,   // 32 rj data
                       rkd_value    ,   // 32 rk data
                       ds_pc        ,   // 32  //跳转pc
                       res_from_mem            //rd data from mem
                    };

assign ds_ready_go    = no_wait;//针对于本阶段

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;//->  !ds_valid || (ds_ready_go && es_allowin) 当本阶段ready 并且 es allow in

assign ds_to_es_valid = ds_valid && ds_ready_go ;//ds_valid 来自于fs_to_ds_valid 只有在时钟的上升沿后才会变化
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;

    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin //valid 和 allowin 握手
        fs_to_ds_bus_r <= fs_to_ds_bus;     //寄存数据后，组合逻辑译码, 

    end
end


endmodule
