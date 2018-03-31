# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_0 {
  DIN_WIDTH 8 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {
  NUM_PORTS 8
}

set prop_list {}
for {set i 0} {$i <= 7} {incr i} {
  lappend prop_list IN${i}_WIDTH 32
}
set_property -dict $prop_list [get_bd_cells concat_0]

for {set i 0} {$i <= 7} {incr i} {
  connect_bd_net [get_bd_pins concat_0/In$i] [get_bd_pins /adc_0/m_axis_tdata]
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_1 {
  NUM_PORTS 16
}

set prop_list {}
for {set i 0} {$i <= 15} {incr i} {
  lappend prop_list IN${i}_WIDTH 1
}
set_property -dict $prop_list [get_bd_cells concat_1]

for {set i 0} {$i <= 15} {incr i} {
  connect_bd_net [get_bd_pins concat_1/In$i] [get_bd_pins /adc_0/m_axis_tvalid]
}

# Create axis_switch
cell xilinx.com:ip:axis_switch:1.1 switch_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 2
  ROUTING_MODE 1
  NUM_SI 16
  NUM_MI 8
} {
  s_axis_tdata concat_0/dout
  s_axis_tvalid concat_1/dout
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

set prop_list {}
for {set i 0} {$i <= 7} {incr i} {
  for {set j 0} {$j <= 15} {incr j} {
    if {$i == $j / 2} continue
    lappend prop_list CONFIG.M[format %02d $i]_S[format %02d $j]_CONNECTIVITY 0
  }
}
set_property -dict $prop_list [get_bd_cells switch_0]

unset prop_list

for {set i 0} {$i <= 7} {incr i} {

  # Create xlslice
  cell xilinx.com:ip:xlslice:1.0 slice_[expr $i + 1] {
    DIN_WIDTH 256 DIN_FROM [expr 32 * $i + 31] DIN_TO [expr 32 * $i] DOUT_WIDTH 32
  }

  # Create axis_constant
  cell pavel-demin:user:axis_constant:1.0 phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 1]/Dout
    aclk /pll_0/clk_out1
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler:6.0 dds_$i {
    DDS_CLOCK_RATE 125
    SPURIOUS_FREE_DYNAMIC_RANGE 138
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 24
    DSP48_USE Minimal
    NEGATIVE_SINE true
  } {
    S_AXIS_PHASE phase_$i/M_AXIS
    aclk /pll_0/clk_out1
  }

}

# Create axis_lfsr
cell pavel-demin:user:axis_lfsr:1.0 lfsr_0 {} {
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

for {set i 0} {$i <= 15} {incr i} {

  # Create xlslice
  cell xilinx.com:ip:xlslice:1.0 adc_slice_$i {
    DIN_WIDTH 128 DIN_FROM [expr 16 * ($i / 2) + 13] DIN_TO [expr 16 * ($i / 2)] DOUT_WIDTH 14
  } {
    Din switch_0/m_axis_tdata
  }

  # Create xlslice
  cell xilinx.com:ip:xlslice:1.0 dds_slice_$i {
    DIN_WIDTH 48 DIN_FROM [expr 24 * ($i % 2) + 23] DIN_TO [expr 24 * ($i % 2)] DOUT_WIDTH 24
  } {
    Din dds_[expr $i / 2]/m_axis_data_tdata
  }

  cell xilinx.com:ip:xbip_dsp48_macro:3.0 mult_$i {
    INSTRUCTION1 RNDSIMPLE(A*B+CARRYIN)
    A_WIDTH.VALUE_SRC USER
    B_WIDTH.VALUE_SRC USER
    OUTPUT_PROPERTIES User_Defined
    A_WIDTH 24
    B_WIDTH 14
    P_WIDTH 25
  } {
    A dds_slice_$i/Dout
    B adc_slice_$i/Dout
    CARRYIN lfsr_0/m_axis_tdata
    CLK /pll_0/clk_out1
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler:4.0 cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Fixed
    FIXED_OR_INITIAL_RATE 25
    INPUT_SAMPLE_FREQUENCY 125
    CLOCK_FREQUENCY 125
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 24
    USE_XTREME_DSP_SLICE false
    HAS_DOUT_TREADY true
    HAS_ARESETN true
  } {
    s_axis_data_tdata mult_$i/P
    s_axis_data_tvalid const_0/dout
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner:1.1 comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 3
  NUM_SI 16
} {
  S00_AXIS cic_0/M_AXIS_DATA
  S01_AXIS cic_1/M_AXIS_DATA
  S02_AXIS cic_2/M_AXIS_DATA
  S03_AXIS cic_3/M_AXIS_DATA
  S04_AXIS cic_4/M_AXIS_DATA
  S05_AXIS cic_5/M_AXIS_DATA
  S06_AXIS cic_6/M_AXIS_DATA
  S07_AXIS cic_7/M_AXIS_DATA
  S08_AXIS cic_8/M_AXIS_DATA
  S09_AXIS cic_9/M_AXIS_DATA
  S10_AXIS cic_10/M_AXIS_DATA
  S11_AXIS cic_11/M_AXIS_DATA
  S12_AXIS cic_12/M_AXIS_DATA
  S13_AXIS cic_13/M_AXIS_DATA
  S14_AXIS cic_14/M_AXIS_DATA
  S15_AXIS cic_15/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 48
  M_TDATA_NUM_BYTES 3
} {
  S_AXIS comb_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create cic_compiler
cell xilinx.com:ip:cic_compiler:4.0 cic_16 {
  INPUT_DATA_WIDTH.VALUE_SRC USER
  FILTER_TYPE Decimation
  NUMBER_OF_STAGES 6
  SAMPLE_RATE_CHANGES Fixed
  FIXED_OR_INITIAL_RATE 125
  INPUT_SAMPLE_FREQUENCY 5
  CLOCK_FREQUENCY 125
  NUMBER_OF_CHANNELS 16
  INPUT_DATA_WIDTH 24
  QUANTIZATION Truncation
  OUTPUT_DATA_WIDTH 32
  USE_XTREME_DSP_SLICE false
  HAS_DOUT_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA conv_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_0 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-1.5065458369e-08, 4.0943728857e-09, 9.7221813080e-09, -3.2389062140e-08, -1.4704207189e-07, -3.2339733379e-07, -4.9277029618e-07, -5.2462312568e-07, -2.5263380040e-07, 4.6611149321e-07, 1.6696422638e-06, 3.2128528431e-06, 4.7273710273e-06, 5.6526738863e-06, 5.3555081537e-06, 3.3260010889e-06, -5.9508829463e-07, -6.0310219044e-06, -1.2007021855e-05, -1.7073033543e-05, -1.9624018286e-05, -1.8362675826e-05, -1.2782678242e-05, -3.5097068354e-06, 7.6550917123e-06, 1.8079025318e-05, 2.5003695245e-05, 2.6451323853e-05, 2.2057285357e-05, 1.3511349514e-05, 4.3497378821e-06, -9.9289147393e-07, 1.2796435697e-06, 1.2600734569e-05, 3.0703495559e-05, 4.9260059297e-05, 5.8902344885e-05, 4.9657448885e-05, 1.4354724204e-05, -4.7883035588e-05, -1.2920864781e-04, -2.1276404771e-04, -2.7519275892e-04, -2.9186378215e-04, -2.4383650036e-04, -1.2482612377e-04, 5.3957883204e-05, 2.6302891961e-04, 4.5898169499e-04, 5.9372618228e-04, 6.2679259286e-04, 5.3762021386e-04, 3.3416432513e-04, 5.4594819494e-05, -2.3962513534e-04, -4.7866644375e-04, -6.0408034613e-04, -5.8809954355e-04, -4.4637889169e-04, -2.3892619508e-04, -5.6618781674e-05, 5.3356146002e-06, -1.1870495686e-04, -4.3275426166e-04, -8.5960465448e-04, -1.2429139941e-03, -1.3757490070e-03, -1.0536102009e-03, -1.4236718113e-04, 1.3549428330e-03, 3.2518613288e-03, 5.1709688845e-03, 6.5868955023e-03, 6.9210628960e-03, 5.6763883194e-03, 2.5878461347e-03, -2.2437481048e-03, -8.2694222584e-03, -1.4490042865e-02, -1.9550023545e-02, -2.1923295848e-02, -2.0167530662e-02, -1.3204825143e-02, -5.7637574971e-04, 1.7381898628e-02, 3.9485221516e-02, 6.3789404308e-02, 8.7819539431e-02, 1.0890632987e-01, 1.2457600210e-01, 1.3292704532e-01, 1.3292704532e-01, 1.2457600210e-01, 1.0890632987e-01, 8.7819539431e-02, 6.3789404308e-02, 3.9485221516e-02, 1.7381898628e-02, -5.7637574971e-04, -1.3204825143e-02, -2.0167530662e-02, -2.1923295848e-02, -1.9550023545e-02, -1.4490042865e-02, -8.2694222584e-03, -2.2437481048e-03, 2.5878461347e-03, 5.6763883194e-03, 6.9210628960e-03, 6.5868955023e-03, 5.1709688845e-03, 3.2518613288e-03, 1.3549428330e-03, -1.4236718113e-04, -1.0536102009e-03, -1.3757490070e-03, -1.2429139941e-03, -8.5960465448e-04, -4.3275426166e-04, -1.1870495686e-04, 5.3356146002e-06, -5.6618781674e-05, -2.3892619508e-04, -4.4637889169e-04, -5.8809954355e-04, -6.0408034613e-04, -4.7866644375e-04, -2.3962513534e-04, 5.4594819494e-05, 3.3416432513e-04, 5.3762021386e-04, 6.2679259286e-04, 5.9372618228e-04, 4.5898169499e-04, 2.6302891961e-04, 5.3957883204e-05, -1.2482612377e-04, -2.4383650036e-04, -2.9186378215e-04, -2.7519275892e-04, -2.1276404771e-04, -1.2920864781e-04, -4.7883035588e-05, 1.4354724204e-05, 4.9657448885e-05, 5.8902344885e-05, 4.9260059297e-05, 3.0703495559e-05, 1.2600734569e-05, 1.2796435697e-06, -9.9289147392e-07, 4.3497378821e-06, 1.3511349514e-05, 2.2057285357e-05, 2.6451323853e-05, 2.5003695245e-05, 1.8079025318e-05, 7.6550917123e-06, -3.5097068354e-06, -1.2782678242e-05, -1.8362675826e-05, -1.9624018286e-05, -1.7073033543e-05, -1.2007021855e-05, -6.0310219044e-06, -5.9508829463e-07, 3.3260010889e-06, 5.3555081537e-06, 5.6526738863e-06, 4.7273710273e-06, 3.2128528431e-06, 1.6696422638e-06, 4.6611149321e-07, -2.5263380040e-07, -5.2462312568e-07, -4.9277029618e-07, -3.2339733379e-07, -1.4704207189e-07, -3.2389062140e-08, 9.7221813080e-09, 4.0943728857e-09, -1.5065458369e-08}
  COEFFICIENT_WIDTH 32
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  RATE_CHANGE_TYPE Fixed_Fractional
  INTERPOLATION_RATE 3
  DECIMATION_RATE 5
  NUMBER_CHANNELS 16
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 0.04
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 33
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA cic_16/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 5
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS fir_0/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler:7.2 fir_1 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-1.4649009092e-08, -3.2041290183e-08, 5.2019207045e-09, 2.1138130330e-08, 3.8243587270e-09, 2.1724694147e-08, 8.8870648979e-09, -1.0211458034e-07, -7.5764793614e-08, 2.1052119329e-07, 2.3564203975e-07, -3.1504540455e-07, -5.2432236294e-07, 3.5711484953e-07, 9.6086178448e-07, -2.5315236308e-07, -1.5319475153e-06, -9.6022840318e-08, 2.1775325712e-06, 7.8703954727e-07, -2.7823327945e-06, -1.8884223236e-06, 3.1776833458e-06, 3.4112430672e-06, -3.1573535858e-06, -5.2819364630e-06, 2.5086165999e-06, 7.3247520375e-06, -1.0565995107e-06, -9.2616000398e-06, -1.2840368172e-06, 1.0735418071e-05, 4.4597355214e-06, -1.1359725200e-05, -8.2434743039e-06, 1.0791333280e-05, 1.2227096460e-05, -8.8188702532e-06, -1.5853967569e-05, 5.4482045623e-06, 1.8492840651e-05, -9.6982194788e-07, -1.9554746811e-05, -4.0168976829e-06, 1.8637672950e-05, 8.6396185307e-06, -1.5677201604e-05, -1.1860885979e-05, 1.1072100725e-05, 1.2656884062e-05, -5.7504893761e-06, -1.0251254409e-05, 1.1443024712e-06, 4.3717205881e-06, 9.5017329308e-07, 4.5162717473e-06, 1.3686999595e-06, -1.5053343788e-05, -9.7472785622e-06, 2.4958871181e-05, 2.5151428949e-05, -3.1184924032e-05, -4.7458647551e-05, 3.0247941576e-05, 7.5120841338e-05, -1.8755861047e-05, -1.0501198695e-04, -5.9422815702e-06, 1.3251966795e-04, 4.5061768676e-05, -1.5193311293e-04, -9.7762214754e-05, 1.5713081313e-04, 1.6073382003e-04, -1.4251808084e-04, -2.2811677101e-04, 1.0410616635e-04, 2.9184938150e-04, -4.0574103124e-05, -3.4248678779e-04, -4.5880867256e-05, 3.7045612304e-04, 1.4910246371e-04, -3.6763896239e-04, -2.5914156348e-04, 3.2903457819e-04, 3.6306800191e-04, -2.5433912874e-04, -4.4657048633e-04, 1.4900328397e-04, 4.9611643217e-04, -2.4576889265e-05, -5.0151467577e-04, -1.0193695412e-04, 4.5851364814e-04, 2.0983131295e-04, -3.7101070837e-04, -2.7751827829e-04, 2.5241323713e-04, 2.8621289357e-04, -1.2573018304e-04, -2.2408585631e-04, 2.2079603873e-05, 9.0334609148e-05, 2.2523010402e-05, 1.0147656828e-04, 2.7988324938e-05, -3.2151935195e-04, -2.0369222131e-04, 5.2366921853e-04, 5.2175409830e-04, -6.4819690565e-04, -9.7993976103e-04, 6.2680905142e-04, 1.5509883406e-03, -3.9031555011e-04, -2.1790939387e-03, -1.2174742343e-04, 2.7792444763e-03, 9.5031980375e-04, -3.2400274433e-03, -2.1059217427e-03, 3.4301476070e-03, 3.5588689473e-03, -3.2084756865e-03, -5.2317914463e-03, 2.4369869716e-03, 6.9954394024e-03, -9.9552395005e-04, -8.6683589752e-03, -1.2030688912e-03, 1.0020194311e-02, 4.1985057545e-03, -1.0778733910e-02, -7.9725645790e-03, 1.0636221763e-02, 1.2440920262e-02, -9.2541271695e-03, -1.7450933241e-02, 6.2568368990e-03, 2.2783372553e-02, -1.2011812867e-03, -2.8156136033e-02, -6.5100448079e-03, 3.3222161291e-02, 1.7853844768e-02, -3.7535967260e-02, -3.4816453730e-02, 4.0382781032e-02, 6.2496025733e-02, -3.9837252590e-02, -1.1894969182e-01, 2.3958441948e-02, 3.2898397250e-01, 4.9045083671e-01, 3.2898397250e-01, 2.3958441948e-02, -1.1894969182e-01, -3.9837252590e-02, 6.2496025733e-02, 4.0382781032e-02, -3.4816453730e-02, -3.7535967260e-02, 1.7853844768e-02, 3.3222161291e-02, -6.5100448079e-03, -2.8156136033e-02, -1.2011812867e-03, 2.2783372553e-02, 6.2568368990e-03, -1.7450933241e-02, -9.2541271695e-03, 1.2440920262e-02, 1.0636221763e-02, -7.9725645790e-03, -1.0778733910e-02, 4.1985057545e-03, 1.0020194311e-02, -1.2030688912e-03, -8.6683589752e-03, -9.9552395005e-04, 6.9954394024e-03, 2.4369869716e-03, -5.2317914463e-03, -3.2084756865e-03, 3.5588689473e-03, 3.4301476070e-03, -2.1059217427e-03, -3.2400274433e-03, 9.5031980375e-04, 2.7792444763e-03, -1.2174742343e-04, -2.1790939387e-03, -3.9031555011e-04, 1.5509883406e-03, 6.2680905142e-04, -9.7993976103e-04, -6.4819690565e-04, 5.2175409830e-04, 5.2366921853e-04, -2.0369222131e-04, -3.2151935195e-04, 2.7988324938e-05, 1.0147656828e-04, 2.2523010402e-05, 9.0334609148e-05, 2.2079603873e-05, -2.2408585631e-04, -1.2573018304e-04, 2.8621289357e-04, 2.5241323713e-04, -2.7751827829e-04, -3.7101070837e-04, 2.0983131295e-04, 4.5851364814e-04, -1.0193695412e-04, -5.0151467577e-04, -2.4576889265e-05, 4.9611643217e-04, 1.4900328397e-04, -4.4657048633e-04, -2.5433912874e-04, 3.6306800191e-04, 3.2903457819e-04, -2.5914156348e-04, -3.6763896239e-04, 1.4910246371e-04, 3.7045612304e-04, -4.5880867256e-05, -3.4248678779e-04, -4.0574103124e-05, 2.9184938150e-04, 1.0410616635e-04, -2.2811677101e-04, -1.4251808084e-04, 1.6073382003e-04, 1.5713081313e-04, -9.7762214754e-05, -1.5193311293e-04, 4.5061768676e-05, 1.3251966795e-04, -5.9422815702e-06, -1.0501198695e-04, -1.8755861047e-05, 7.5120841338e-05, 3.0247941576e-05, -4.7458647551e-05, -3.1184924032e-05, 2.5151428949e-05, 2.4958871181e-05, -9.7472785622e-06, -1.5053343788e-05, 1.3686999595e-06, 4.5162717473e-06, 9.5017329308e-07, 4.3717205881e-06, 1.1443024712e-06, -1.0251254409e-05, -5.7504893761e-06, 1.2656884062e-05, 1.1072100725e-05, -1.1860885979e-05, -1.5677201604e-05, 8.6396185307e-06, 1.8637672950e-05, -4.0168976829e-06, -1.9554746811e-05, -9.6982194788e-07, 1.8492840651e-05, 5.4482045623e-06, -1.5853967569e-05, -8.8188702532e-06, 1.2227096460e-05, 1.0791333280e-05, -8.2434743039e-06, -1.1359725200e-05, 4.4597355214e-06, 1.0735418071e-05, -1.2840368172e-06, -9.2616000398e-06, -1.0565995107e-06, 7.3247520375e-06, 2.5086165999e-06, -5.2819364630e-06, -3.1573535858e-06, 3.4112430672e-06, 3.1776833458e-06, -1.8884223236e-06, -2.7823327945e-06, 7.8703954727e-07, 2.1775325712e-06, -9.6022840318e-08, -1.5319475153e-06, -2.5315236308e-07, 9.6086178448e-07, 3.5711484953e-07, -5.2432236294e-07, -3.1504540455e-07, 2.3564203975e-07, 2.1052119329e-07, -7.5764793614e-08, -1.0211458034e-07, 8.8870648979e-09, 2.1724694147e-08, 3.8243587270e-09, 2.1138130330e-08, 5.2019207045e-09, -3.2041290183e-08, -1.4649009092e-08}
  COEFFICIENT_WIDTH 32
  QUANTIZATION Maximize_Dynamic_Range
  BESTPRECISION true
  FILTER_TYPE Decimation
  DECIMATION_RATE 2
  NUMBER_CHANNELS 16
  NUMBER_PATHS 1
  SAMPLE_FREQUENCY 0.024
  CLOCK_FREQUENCY 125
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 33
  M_DATA_HAS_TREADY true
  HAS_ARESETN true
} {
  S_AXIS_DATA subset_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 subset_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 5
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS fir_1/M_AXIS_DATA
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create floating_point
cell xilinx.com:ip:floating_point:7.1 fp_0 {
  OPERATION_TYPE Fixed_to_float
  A_PRECISION_TYPE.VALUE_SRC USER
  C_A_EXPONENT_WIDTH.VALUE_SRC USER
  C_A_FRACTION_WIDTH.VALUE_SRC USER
  A_PRECISION_TYPE Custom
  C_A_EXPONENT_WIDTH 2
  C_A_FRACTION_WIDTH 30
  RESULT_PRECISION_TYPE Single
  HAS_ARESETN true
} {
  S_AXIS_A subset_1/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 64
} {
  S_AXIS fp_0/M_AXIS_RESULT
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_8 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 64
  M_TDATA_NUM_BYTES 8
  NUM_MI 8
  M00_TDATA_REMAP {tdata[31:0],tdata[63:32]}
  M01_TDATA_REMAP {tdata[95:64],tdata[127:96]}
  M02_TDATA_REMAP {tdata[159:128],tdata[191:160]}
  M03_TDATA_REMAP {tdata[223:192],tdata[255:224]}
  M04_TDATA_REMAP {tdata[287:256],tdata[319:288]}
  M05_TDATA_REMAP {tdata[351:320],tdata[383:352]}
  M06_TDATA_REMAP {tdata[415:384],tdata[447:416]}
  M07_TDATA_REMAP {tdata[479:448],tdata[511:480]}
} {
  S_AXIS conv_1/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /rst_0/peripheral_aresetn
}

for {set i 0} {$i <= 7} {incr i} {

  # Create fifo_generator
  cell xilinx.com:ip:fifo_generator:13.1 fifo_generator_$i {
    PERFORMANCE_OPTIONS First_Word_Fall_Through
    INPUT_DATA_WIDTH 64
    INPUT_DEPTH 512
    OUTPUT_DATA_WIDTH 32
    OUTPUT_DEPTH 1024
    READ_DATA_COUNT true
    READ_DATA_COUNT_WIDTH 11
  } {
    clk /pll_0/clk_out1
    srst slice_0/Dout
  }

  # Create axis_fifo
  cell pavel-demin:user:axis_fifo:1.0 fifo_[expr $i + 1] {
    S_AXIS_TDATA_WIDTH 64
    M_AXIS_TDATA_WIDTH 32
  } {
    S_AXIS bcast_8/M0${i}_AXIS
    FIFO_READ fifo_generator_$i/FIFO_READ
    FIFO_WRITE fifo_generator_$i/FIFO_WRITE
    aclk /pll_0/clk_out1
  }

  # Create axi_axis_reader
  cell pavel-demin:user:axi_axis_reader:1.0 reader_$i {
    AXI_DATA_WIDTH 32
  } {
    S_AXIS fifo_[expr $i + 1]/M_AXIS
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

}
