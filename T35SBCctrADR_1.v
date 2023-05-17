/********************************************************************
*   FILE:  T35SBCctrADR_1_top.v                                     *
*                                                                   *
*   This is a simple project that increments the S-100 Address      *
*   lines on John Monahan's FPGA SBC board via the T35.             *
*   Adress lines 0-15 increment up at a 1MHz rate using PLL0        *
*   while address lines 16-19 count backwards (19 - 16).            *
*   TFOX, N4TLF September 11, 2022   You are free to use it         *
*       however you like.  No warranty expressed or implied         *
*                                                                   *
*   A 27-bit counter is used to divide the 2MHz PLL clock output    *
        to various slower frequencies                               *
*   This version runs much slower (helping with visual inspection). *
*       Adjusting the "assign" statements for the two Address and   *
*       SBCLEDS busses can change the operating speed.              *
*   Currently, A0 runs at approx. 488Hz, SBCLED D0 approx 2Hz.      *
*   Assign S100adr0_15 to counter[15:0] sets A0 to approx. 1MHz     *
*    TFOX: May 15, 2023  Added Data OUT LED incrementing            *
********************************************************************/

module  T35SBCctrADR_1_top (
    pll0_LOCKED,        // signal shows the PLL is locked
    pll0_2MHz,          // 2MHz PLL out that is "master" clock signal
    s100_n_RESET,       // on board reset push button
    F_in_sdsb,          // FPGA STATUS disable input
    F_in_cdsb,          // FPGA CONTROL disable input
    S100adr0_15,        // The regular 16 address bits
    S100adr16_19,       // These are wires backwards, so
                        // lowest bit is A19, highest is A16
    sbcLEDS,            // The SBC LEDs also show activity
    s100_DO,            // S100 Data OUT bus
    s100_pDBIN,         // S100 pDBIN (proc. Data Bus In signal)
    s100_pSYNC,         // S100 pSYNC (proc. Sync signal)
    s100_pSTVAL,        // S100 pSTVAL (proc. Status Valid)
    s100_n_pWR,         // Active low processor write signal
    s100_sMWRT,         // proc. Status Memory Write signal
    seg7,               // T35 seven-segment display bus
    seg7_dp,            // T35 seven-segment decimal point
                        //   used as a visual "heartbeat"
    boardActive,        // SBC LED to show board is active
    F_add_oe,           // FPGA SBC drivers Address output enable
    F_bus_stat_oe,      // FPGA SBC Status output enable
    F_bus_ctl_oe,       // FPGA SBC Control output enable
    F_out_DO_oe,        // FPGA SBC Data Out output enable
    F_out_DI_oe,        // FPGA SBC Data In output enable
    s100_CDSB,          // FPGA SBC Control DISABLE (S100-18)
    s100_SDSB,          // FPGA SDSB Status and Address DISABLE (S100-19)
    s100_sINTA,
    s100_sOUT,
    s100_sINP,
    s100_PHANTOM);

    input   pll0_LOCKED;        // PLL is locked (good)
    input   pll0_2MHz;          // 2MHz PLL Clock signal
    input   s100_n_RESET;       // onboard active low reset
    input   F_in_sdsb;
    input   F_in_cdsb;

    output  [15:0] S100adr0_15; // S100 Address bus 0:15
    output  [3:0] S100adr16_19; // S100 Address but 16-19
    output  [7:0] sbcLEDS;      // "F_BAR" LEDs on SBC board
    output  [7:0] s100_DO;      // s100 Data OUT bus
    output  s100_pDBIN;             // GPIOT_RXP21
    output  s100_pSYNC;             // GPIOT_RXP20
    output  s100_pSTVAL;            // GPIOT_RXN21
    output  s100_n_pWR;             // GPIOT_RXP20
    output  s100_sMWRT;             // GPIOR_121
    output  [6:0] seg7;             // T35 7-segment output bus
    output  seg7_dp;                // T35 7-segment decimal point
    output  boardActive;            // GPIOT_RXN20
    output  F_add_oe;               // FPGA ADDRESS buffers output enable
    output  F_bus_stat_oe;          // FPGA STATUS buffer output enable
    output  F_bus_ctl_oe;           // FPGA CONTROL buffer output enable
    output  F_out_DO_oe;            // FPGA DATA OUT buffer output enable
    output  F_out_DI_oe;            // FPGA DATA IN buffer enable
    output  s100_CDSB;              // Control Disable to S100 bus
    output  s100_SDSB;              // STATUS Disable to S100 bus
    output  s100_sINTA;             // S100 INTA OUTPUT
    output  s100_sOUT;              // S100 sOUT to flash about one second
    output  s100_sINP;              // S100 sIN flash opposite sOUT
    output  s100_PHANTOM;           // turn OFF Phantom LED
    
wire       n_reset;
reg [26:0]  counter;            // 27-bit counter for A0 to A15

/****************************************************************************
*       SET UP SEVEN SEGMENT DISPLAY                                        *
****************************************************************************/
assign seg7 = 7'b1111001;           // Set T35 7-segment to the number "1"
assign seg7_dp = counter[20];       // blink T35 decimal point roughly 1sec

/****************************************************************************
*       TURN ON SBC S100 BUFFERS                                            *
****************************************************************************/
assign s100_CDSB = 1'b1;                // set the S100 CDSB
assign s100_SDSB = 1'b1;                // set the S100 SDSB and ADSB
assign F_add_oe = !F_in_sdsb;           // Address Bus enable  GPIOB_TXN17
assign F_bus_stat_oe = !F_in_sdsb;      // Status bus enable   GPIOB_TXN19
assign F_bus_ctl_oe = !F_in_cdsb;       // Control bus enable  GPIO_R120
assign F_out_DO_oe = !F_in_sdsb;        // S100 Data OUT bus   GPIOL_114
assign F_out_DI_oe = !F_in_sdsb;        // S100 Data OUT bus   GPIOL_114

/****************************************************************************
*       SET UP THE COUNTER OUTPUTS TO S100 BUS PINS                         *
****************************************************************************/
assign S100adr0_15 = counter[26:11];    // Change to [15:0] for A0=1MHz
assign S100adr16_19 = counter[21:18];   // run Address 16-19 backwards
assign s100_DO = counter[26:19];        // and run Data OUT backwards
assign sbcLEDS = ~(counter[26:19]);     // LEDs active low, complement

/****************************************************************************
*    FAKE VARIOUS S100 SIGNALS FOR BUS DISPLAY                              *
****************************************************************************/
assign n_reset = s100_n_RESET;          // Board and S100 reset in
assign boardActive = !pll0_LOCKED;      // Show that the PLL is locked
assign s100_pDBIN = pll0_2MHz;          // Fake an S100 pDBIN signal
assign s100_pSYNC = pll0_2MHz;          // Fake an S100 pSYNC signal
assign s100_pSTVAL = !pll0_2MHz;        // Fake an S100 pSTVAL signal
assign s100_n_pWR = 1'b1;               // keep processor write high
assign s100_sMWRT = 1'b0;               // keep memory write low
assign s100_sINTA = 1'b0;               // keep processot INTA low
assign s100_sOUT = counter[20];         // Flash the S100 sOUT LED
assign s100_sINP = !counter[20];        // Flash sINP LED opposite sOUT
assign s100_PHANTOM = 1'b0;             // turn OFF PHANTOM LED for now

/****************************************************************************
*       THE COUNTER ITSELF                                                  *
****************************************************************************/
always @(posedge pll0_2MHz)         // at every positive edge of 2MHz PLL out,
    begin
        if(!s100_n_RESET) begin         // if reset set low...
            counter <= 27'b0;           // reset counter to 0
        end                             // end of resetting everything
        else
            counter <= counter + 1;     // just increment counter
                                        // it falls through max back to zero
    end
    
endmodule
