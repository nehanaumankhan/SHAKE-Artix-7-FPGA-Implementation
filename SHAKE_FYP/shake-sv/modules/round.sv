`timescale 1ns / 1ps

import keccak_pkg::STATE_WIDTH;
import keccak_pkg::w;

module keccak_round (
  input  logic [STATE_WIDTH-1:0] rin, // current_state 1600 bits
  input  logic [w-1:0]           rc,  // round constant for iota step
  output logic [STATE_WIDTH-1:0] rout // permuted_state
);

    // rotate-left function
    function automatic logic [w-1:0] rolx(input logic [w-1:0] x, input int r);
    rolx = (x << r) | (x >> (w-r));
    endfunction

    // lane signals
    logic [w-1:0] Aba, Abe, Abi, Abo, Abu;
    logic [w-1:0] Aga, Age, Agi, Ago, Agu;
    logic [w-1:0] Aka, Ake, Aki, Ako, Aku;
    logic [w-1:0] Ama, Ame, Ami, Amo, Amu;
    logic [w-1:0] Asa, Ase, Asi, Aso, Asu;

    // intermediate θ, ρ/π, χ signals
    logic [w-1:0] Ca, Ce, Ci, Co, Cu;
    logic [w-1:0] Da, De, Di, Do, Du;

    // //  Intermediate state after ρ (rotation) and π (Permutation).
    logic [w-1:0] Bba, Bbe, Bbi, Bbo, Bbu;
    logic [w-1:0] Bga, Bge, Bgi, Bgo, Bgu;
    logic [w-1:0] Bka, Bke, Bki, Bko, Bku;
    logic [w-1:0] Bma, Bme, Bmi, Bmo, Bmu;
    logic [w-1:0] Bsa, Bse, Bsi, Bso, Bsu;

    // // E: Output state after χ (Non-linear) and i (Round constant).
    logic [w-1:0] Eba, Ebe, Ebi, Ebo, Ebu;
    logic [w-1:0] Ega, Ege, Egi, Ego, Egu;
    logic [w-1:0] Eka, Eke, Eki, Eko, Eku;
    logic [w-1:0] Ema, Eme, Emi, Emo, Emu;
    logic [w-1:0] Esa, Ese, Esi, Eso, Esu;

    // extract the 25 lanes from the 1600-bit input
    // b, g, k, m, s (represents plane - x)
    // a, e, i, o, u (represents sheet - y)
    // 25 64-bits w slice(lane) is assigned
    assign Aba = rin[1599:1536]; assign Abe = rin[1535:1472]; assign Abi = rin[1471:1408]; assign Abo = rin[1407:1344]; assign Abu = rin[1343:1280];
    assign Aga = rin[1279:1216]; assign Age = rin[1215:1152]; assign Agi = rin[1151:1088]; assign Ago = rin[1087:1024]; assign Agu = rin[1023: 960];
    assign Aka = rin[ 959: 896]; assign Ake = rin[ 895: 832]; assign Aki = rin[ 831: 768]; assign Ako = rin[ 767: 704]; assign Aku = rin[ 703: 640];
    assign Ama = rin[ 639: 576]; assign Ame = rin[ 575: 512]; assign Ami = rin[ 511: 448]; assign Amo = rin[ 447: 384]; assign Amu = rin[ 383: 320];
    assign Asa = rin[ 319: 256]; assign Ase = rin[ 255: 192]; assign Asi = rin[ 191: 128]; assign Aso = rin[ 127:  64]; assign Asu = rin[  63:   0];

    // θ step
    assign Ca = Aba ^ Aga ^ Aka ^ Ama ^ Asa; // column-wise xoring - Parity
    assign Ce = Abe ^ Age ^ Ake ^ Ame ^ Ase;
    assign Ci = Abi ^ Agi ^ Aki ^ Ami ^ Asi;
    assign Co = Abo ^ Ago ^ Ako ^ Amo ^ Aso;
    assign Cu = Abu ^ Agu ^ Aku ^ Amu ^ Asu;

    assign Da = Cu ^ rolx(Ce, 1); // Modifier
    assign De = Ca ^ rolx(Ci, 1);
    assign Di = Ce ^ rolx(Co, 1);
    assign Do = Ci ^ rolx(Cu, 1);
    assign Du = Co ^ rolx(Ca, 1);

    
    // Theta - xor(θ), Rho - rolx(ρ), and Pi - assign(π)
    // Input A to Intermediate B

    // Row b
    assign Bba = Aba ^ Da;                // (0,0) -> (0,0) rot 0
    assign Bbe = rolx(Age ^ De, 44);      // (1,1) -> (0,1) rot 44
    assign Bbi = rolx(Aki ^ Di, 43);      // (2,2) -> (0,2) rot 43
    assign Bbo = rolx(Amo ^ Do, 21);      // (3,3) -> (0,3) rot 21
    assign Bbu = rolx(Asu ^ Du, 14);      // (4,4) -> (0,4) rot 14

    // Row g
    assign Bga = rolx(Abo ^ Do, 28);      // (3,0) -> (1,0) rot 28
    assign Bge = rolx(Agu ^ Du, 20);      // (4,1) -> (1,1) rot 20
    assign Bgi = rolx(Aka ^ Da,  3);      // (0,2) -> (1,2) rot 3
    assign Bgo = rolx(Ame ^ De, 45);      // (1,3) -> (1,3) rot 45
    assign Bgu = rolx(Asi ^ Di, 61);      // (2,4) -> (1,4) rot 61

    // Row k
    assign Bka = rolx(Abe ^ De,  1);      // (1,0) -> (2,0) rot 1
    assign Bke = rolx(Agi ^ Di,  6);      // (2,1) -> (2,1) rot 6
    assign Bki = rolx(Ako ^ Do, 25);      // (3,2) -> (2,2) rot 25
    assign Bko = rolx(Amu ^ Du,  8);      // (4,3) -> (2,3) rot 8
    assign Bku = rolx(Asa ^ Da, 18);      // (0,4) -> (2,4) rot 18

    // Row m
    assign Bma = rolx(Abu ^ Du, 27);      // (4,0) -> (3,0) rot 27
    assign Bme = rolx(Aga ^ Da, 36);      // (0,1) -> (3,1) rot 36
    assign Bmi = rolx(Ake ^ De, 10);      // (1,2) -> (3,2) rot 10
    assign Bmo = rolx(Ami ^ Di, 15);      // (2,3) -> (3,3) rot 15
    assign Bmu = rolx(Aso ^ Do, 56);      // (3,4) -> (3,4) rot 56

    // Row s
    assign Bsa = rolx(Abi ^ Di, 62);      // (2,0) -> (4,0) rot 62
    assign Bse = rolx(Ago ^ Do, 55);      // (3,1) -> (4,1) rot 55
    assign Bsi = rolx(Aku ^ Du, 39);      // (4,2) -> (4,2) rot 39
    assign Bso = rolx(Ama ^ Da, 41);      // (0,3) -> (4,3) rot 41
    assign Bsu = rolx(Ase ^ De,  2);      // (1,4) -> (4,4) rot 2

    // Chi - operations(χ) and Iota - rc(ι)
    // Intermediate B to Output E

    // Row b
    assign Eba = (Bba ^ ((~Bbe) & Bbi)) ^ rc;
    assign Ebe =  Bbe ^ ((~Bbi) & Bbo);
    assign Ebi =  Bbi ^ ((~Bbo) & Bbu);
    assign Ebo =  Bbo ^ ((~Bbu) & Bba);
    assign Ebu =  Bbu ^ ((~Bba) & Bbe);

    // Row g
    assign Ega =  Bga ^ ((~Bge) & Bgi);
    assign Ege =  Bge ^ ((~Bgi) & Bgo);
    assign Egi =  Bgi ^ ((~Bgo) & Bgu);
    assign Ego =  Bgo ^ ((~Bgu) & Bga);
    assign Egu =  Bgu ^ ((~Bga) & Bge);

    // Row k
    assign Eka =  Bka ^ ((~Bke) & Bki);
    assign Eke =  Bke ^ ((~Bki) & Bko);
    assign Eki =  Bki ^ ((~Bko) & Bku);
    assign Eko =  Bko ^ ((~Bku) & Bka);
    assign Eku =  Bku ^ ((~Bka) & Bke);
    
    // Row m
    assign Ema =  Bma ^ ((~Bme) & Bmi);
    assign Eme =  Bme ^ ((~Bmi) & Bmo);
    assign Emi =  Bmi ^ ((~Bmo) & Bmu);
    assign Emo =  Bmo ^ ((~Bmu) & Bma);
    assign Emu =  Bmu ^ ((~Bma) & Bme);

    // Row s
    assign Esa =  Bsa ^ ((~Bse) & Bsi);
    assign Ese =  Bse ^ ((~Bsi) & Bso);
    assign Esi =  Bsi ^ ((~Bso) & Bsu);
    assign Eso =  Bso ^ ((~Bsu) & Bsa);
    assign Esu =  Bsu ^ ((~Bsa) & Bse);

    assign rout = {
        Eba, Ebe, Ebi, Ebo, Ebu,
        Ega, Ege, Egi, Ego, Egu,
        Eka, Eke, Eki, Eko, Eku,
        Ema, Eme, Emi, Emo, Emu,
        Esa, Ese, Esi, Eso, Esu
    };

endmodule
    
