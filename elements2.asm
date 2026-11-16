; ============================================================
;  ELEMENTS  -  Periodic Table Quiz for the Commodore 64
;  Assembler : ACME, target 6510
;
;  BUILD (choose ONE):
;     acme -f cbm -o elements.prg elements.asm
;     acme -DPLAIN=1 -f plain -o elements.prg elements.asm
;  CHECK: the first bytes of the .prg must be   01 08 0b 08 0a 00 9e
;  Run:   LOAD "ELEMENTS.PRG",8,1   then   RUN      (LIST shows 10 SYS2061)
;
;  The game draws the periodic table (118 elements, colour coded by
;  family, odd/even columns alternate normal/reverse so neighbours stay
;  readable), then asks one question per randomly chosen element:
;     1 What is the chemical symbol of <name>?
;     2 Which element has the symbol <sym>?
;     3 What is the atomic number of <name>?
;     4 Which family does <name> belong to?
;     5 Which element is hidden behind ?? in the table?
;  Three answers are offered (keys 1-3): one is right, two are
;  look-alikes: names/symbols starting with the same letter, atomic
;  numbers or table neighbours close by, or other families.
;  Right answer = 1 point. Modes: 10, 20 or 30 questions, each mode has
;  its own high score (kept while the program is loaded).
;
;  Screen output is written straight into screen RAM, using the
;  upper/lower case character set, so symbols read "Fe", not "FE".
; ============================================================

!cpu 6510

; ---------------- KERNAL ----------------
CHROUT   = $ffd2
GETIN    = $ffe4

; ---------------- zero page pointers ----------------
str_lo   = $f7          ; string pointer
str_hi   = $f8
tp_lo    = $f9          ; temp pointer
tp_hi    = $fa
sp_lo    = $fb          ; screen RAM pointer
sp_hi    = $fc
cp_lo    = $fd          ; colour RAM pointer
cp_hi    = $fe

N_ELEM   = 118

; ---------------- macros ----------------
!macro say .s {
    lda #<.s
    ldy #>.s
    jsr puts
}
!macro goto .x,.y {
    lda #.x
    sta cx
    lda #.y
    sta cy
    jsr gotoxy
}
!macro colr .c {
    lda #.c
    sta ccol
}

; ============================================================
;  BASIC stub:  10 SYS 2061
; ============================================================
!ifdef PLAIN {
    * = $0801-2
    !word $0801             ; load address (plain format only)
} else {
    * = $0801
}
    !byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

; machine code starts at $080d = 2061

; ============================================================
;  START / MAIN MENU
; ============================================================
!zone start
start
    lda #1
    sta $cc                 ; KERNAL cursor blink off
    lda #$17
    sta $d018               ; screen $0400, upper/lower case characters
    lda #0
    sta $d020
    sta $d021
    jsr init_sid
    jsr build_names
    lda #0
    sta hiscore
    sta hiscore+1
    sta hiscore+2

main_menu
    jsr cls
    jsr draw_title
    jsr draw_table
    jsr draw_menu
.k
    jsr getkey
    sec
    sbc #'1'
    cmp #3
    bcc .mode               ; keys 1,2,3
    cmp #'Q'-'1'
    beq .quit
    jmp .k
.mode
    sta qmode
    tax
    lda qcount,x
    sta qn
    jsr run_quiz
    jmp main_menu
.quit
    jmp quit

!zone quit
quit                        ; back to BASIC
    lda #$15
    sta $d018
    lda #14
    sta $d020
    lda #6
    sta $d021
    lda #14
    sta $0286
    lda #0
    sta $cc
    lda #147
    jsr CHROUT
    rts

; ============================================================
;  QUIZ
; ============================================================
!zone run_quiz
run_quiz
    lda #0
    sta qi
    sta score
    lda #11
    sta cr_y
    lda #14
    sta cr_n
    jsr clear_rows
    jsr pick_elements
.l
    jsr ask_question
    inc qi
    lda qi
    cmp qn
    bne .l
    jmp show_result

; ---- choose qn different random elements ----
!zone pick_elements
pick_elements
    ldx #N_ELEM-1
    lda #0
.c
    sta used,x
    dex
    bpl .c
    sta pk_i
.l
    lda #N_ELEM
    jsr rnd_n
    tax
    lda used,x
    bne .l
    lda #1
    sta used,x
    ldy pk_i
    txa
    sta qlist,y
    inc pk_i
    lda pk_i
    cmp qn
    bne .l
    rts

; ---- one question ----
!zone ask_question
ask_question
    ldx qi
    lda qlist,x
    sta qel
    lda #5
    jsr rnd_n
    sta qtype
    jsr make_options
    lda #11
    sta cr_y
    lda #14
    sta cr_n
    jsr clear_rows
    jsr draw_status
    jsr draw_question
    jsr draw_options
    lda qtype
    cmp #4
    bne +
    lda qel                 ; hide the element behind "??"
    sta dc_i
    lda #1
    sta dc_mode
    jsr draw_cell
+
    jsr get_answer          ; A = 0..2
    cmp cpos
    bne .wrong
    inc score
    jsr show_correct
    jmp .after
.wrong
    jsr show_wrong
.after
    lda qtype
    cmp #4
    bne +
    lda qel                 ; reveal it again
    sta dc_i
    lda #0
    sta dc_mode
    jsr draw_cell
+
    +colr 15
    +goto 1,23
    +say txt_cont
    jmp wait_key

!zone get_answer
get_answer
.w
    jsr getkey
    sec
    sbc #'1'
    cmp #3
    bcs .w
    rts

!zone show_correct
show_correct
    +colr 5
    +goto 1,20
    +say txt_correct
    jmp sfx_ok

!zone show_wrong
show_wrong
    +colr 2
    +goto 1,20
    +say txt_wrong
    +colr 1
    +goto 1,21
    +say txt_answer
    +colr 7
    ldx cpos
    lda opt,x
    jsr print_opt
    jmp sfx_bad

; ---- status line ----
!zone draw_status
draw_status
    +colr 7
    +goto 1,11
    +say txt_q
    lda qi
    clc
    adc #1
    jsr put_num
    +say txt_of
    lda qn
    jsr put_num
    +say txt_score
    lda score
    jsr put_num
    +say txt_high
    ldx qmode
    lda hiscore,x
    jsr put_num
    rts

; ---- the question text ----
!zone draw_question
draw_question
    +colr 1
    +goto 1,13
    lda qtype
    bne .n1
    +say txt_q0a            ; type 0
    +goto 1,14
    lda qel
    jsr put_name
    +say txt_qm
    rts
.n1
    cmp #1
    bne .n2
    +say txt_q1a            ; type 1
    +goto 1,14
    lda qel
    jsr put_sym_t
    +say txt_qm
    rts
.n2
    cmp #2
    bne .n3
    +say txt_q2a            ; type 2
    +goto 1,14
    lda qel
    jsr put_name
    +say txt_qm
    rts
.n3
    cmp #3
    bne .n4
    +say txt_q3a            ; type 3
    +goto 1,14
    lda qel
    jsr put_name
    +say txt_q3b
    rts
.n4
    +say txt_q4a            ; type 4
    +goto 1,14
    +say txt_q4b
    rts

; ---- the three answers ----
!zone draw_options
draw_options
    lda #0
    sta oi
.l
    lda #16
    clc
    adc oi
    sta cy
    lda #3
    sta cx
    jsr gotoxy
    +colr 3
    lda oi
    clc
    adc #'1'
    jsr putc
    lda #')'
    jsr putc
    lda #' '
    jsr putc
    +colr 1
    ldx oi
    lda opt,x
    jsr print_opt
    inc oi
    lda oi
    cmp #3
    bne .l
    rts

; print option value A according to the question type
!zone print_opt
print_opt
    sta po_v
    lda qtype
    cmp #3
    beq .cat
    cmp #2
    beq .num
    cmp #0
    beq .sym
    lda po_v                ; types 1 and 4: element name
    jmp put_name
.sym
    lda po_v
    jmp put_sym_t
.num
    lda po_v
    clc
    adc #1                  ; atomic number = index + 1
    jmp put_num
.cat
    lda po_v
    jmp put_cat

; ============================================================
;  ANSWER OPTIONS: opt[0..2], one of them (cpos) is correct
;  type 0: symbols of elements    (names start with the same letter)
;  type 1: names of elements      (symbols start with the same letter)
;  type 2: atomic numbers         (within +-5 of the right one)
;  type 3: families
;  type 4: names of elements      (neighbours in the table: +-5)
; ============================================================
!zone make_options
make_options
    lda #$ff
    sta opt
    sta opt+1
    sta opt+2
    lda #3
    jsr rnd_n
    sta cpos
    lda qtype
    cmp #3
    bne .el
    ldx qel
    lda el_cat,x
    jmp .st
.el
    lda qel
.st
    ldx cpos
    sta opt,x
    ldx #0
.l
    lda opt,x
    cmp #$ff
    bne .skip
    stx mo_i
    jsr gen_distractor
    ldx mo_i
    sta opt,x
.skip
    inx
    cpx #3
    bne .l
    rts

!zone gen_distractor
gen_distractor              ; returns a wrong, not yet used value in A
    lda #0
    sta tries
.try
    inc tries
    jsr candidate
    cmp #$ff
    beq .try
    ldx #2
.d
    cmp opt,x
    beq .try
    dex
    bpl .d
    rts

!zone candidate
candidate                   ; A = candidate value or $ff (rejected)
    lda qtype
    cmp #3
    beq .cat
    cmp #2
    beq .nb
    cmp #4
    beq .nb
    lda #N_ELEM             ; types 0 and 1: same first letter
    jsr rnd_n
    sta cd_j
    lda tries
    cmp #50
    bcs .ok                 ; too many tries: accept any element
    lda qtype
    bne .symletter
    lda cd_j
    jsr name_first
    sta cd_a
    lda qel
    jsr name_first
    cmp cd_a
    bne .bad
    beq .ok
.symletter
    lda cd_j
    jsr sym_first
    sta cd_a
    lda qel
    jsr sym_first
    cmp cd_a
    bne .bad
.ok
    lda cd_j
    rts
.bad
    lda #$ff
    rts
.cat
    lda #10
    jmp rnd_n
.nb
    lda #11
    jsr rnd_n
    clc
    adc qel
    sec
    sbc #5                  ; qel-5 .. qel+5
    bcc .bad
    cmp #N_ELEM
    bcs .bad
    rts

!zone name_first
name_first                  ; A = element index -> first letter of its name
    tax
    lda name_lo,x
    sta tp_lo
    lda name_hi,x
    sta tp_hi
    ldy #0
    lda (tp_lo),y
    rts

sym_first                   ; A = element index -> first letter of its symbol
    asl
    tax
    lda el_sym,x
    rts

; ---- result screen ----
!zone show_result
show_result
    +colr 7
    +goto 1,12
    +say txt_fin
    +colr 1
    +goto 1,14
    +say txt_mode
    lda qn
    jsr put_num
    +say txt_questions
    +goto 1,15
    +say txt_yours
    lda score
    jsr put_num
    +say txt_slash
    lda qn
    jsr put_num
    lda score               ; rating out of 10
    ldx qmode
    inx
    stx tmpv
    ldy #0
.d
    cmp tmpv
    bcc .dd
    sbc tmpv
    iny
    jmp .d
.dd
    sty rate
    +goto 1,17
    lda rate
    cmp #9
    bcs .r1
    cmp #7
    bcs .r2
    cmp #5
    bcs .r3
    +colr 2
    +say txt_r4
    jmp .hs
.r1
    +colr 5
    +say txt_r1
    jmp .hs
.r2
    +colr 13
    +say txt_r2
    jmp .hs
.r3
    +colr 7
    +say txt_r3
.hs
    ldx qmode
    lda score
    cmp hiscore,x
    beq .old
    bcc .old
    sta hiscore,x           ; new high score for this mode
    +colr 7
    +goto 1,19
    +say txt_newhi
    jmp .end
.old
    +colr 15
    +goto 1,19
    +say txt_hs
    ldx qmode
    lda hiscore,x
    jsr put_num
.end
    +colr 15
    +goto 1,22
    +say txt_cont
    jmp wait_key

; ============================================================
;  PERIODIC TABLE DRAWING
; ============================================================
!zone draw_title
draw_title
    +colr 7
    +goto 10,0
    +say txt_title
    rts

!zone draw_table
draw_table
    lda #0
    sta rev
    sta dc_mode
    ldx #0
.l
    stx dt_i
    stx dc_i
    jsr draw_cell
    ldx dt_i
    inx
    cpx #N_ELEM
    bne .l
    rts

; draw element dc_i; dc_mode 0 = symbol, 1 = hidden ("??", white, reversed)
!zone draw_cell
draw_cell
    ldx dc_i
    lda el_col,x
    asl
    sta cx                  ; two screen columns per table column
    lda el_row,x
    sta cy
    lda el_cat,x
    tay
    lda cat_col,y
    sta ccol
    lda el_col,x
    and #1
    bne .norev
    lda #$80                ; even columns reversed: neighbours stay apart
    bne .setrev
.norev
    lda #0
.setrev
    sta rev
    lda dc_mode
    beq .normal
    lda #1
    sta ccol
    lda #$80
    sta rev
    jsr gotoxy
    lda #'?'
    jsr putc
    lda #'?'
    jsr putc
    jmp .done
.normal
    jsr gotoxy
    lda dc_i
    jsr put_sym
.done
    lda #0
    sta rev
    rts

!zone draw_menu
draw_menu
    +colr 7
    +goto 2,12
    +say txt_intro
    +colr 1
    +goto 2,14
    +say txt_choose
    lda #0
    sta li
.m
    lda #15
    clc
    adc li
    sta cy
    lda #3
    sta cx
    jsr gotoxy
    +colr 3
    lda li
    clc
    adc #'1'
    jsr putc
    +say txt_sp2
    +colr 1
    ldx li
    lda qcount,x
    jsr put_num
    +say txt_qhigh
    ldx li
    lda hiscore,x
    jsr put_num
    inc li
    lda li
    cmp #3
    bne .m
    +colr 15
    +goto 3,18
    +say txt_quitline
    lda #0                  ; colour legend, two columns
    sta li
.lg
    lda li
    lsr
    clc
    adc #20
    sta cy
    lda li
    and #1
    beq .c0
    lda #21
    bne .sx
.c0
    lda #1
.sx
    sta cx
    jsr gotoxy
    ldx li
    lda cat_col,x
    sta ccol
    lda li
    jsr put_cat
    inc li
    lda li
    cmp #10
    bne .lg
    rts

; ============================================================
;  TEXT / SCREEN PRIMITIVES (direct screen RAM + colour RAM)
; ============================================================
!zone cls
cls
    lda #32
    ldx #0
.a
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne .a
    lda #1
.b
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne .b
    lda #0
    sta rev
    lda #1
    sta ccol
    rts

!zone clear_rows
clear_rows                  ; clear cr_n rows starting at row cr_y
.r
    lda cr_y
    sta cy
    lda #0
    sta cx
    jsr gotoxy
    ldy #39
    lda #32
.f
    sta (sp_lo),y
    dey
    bpl .f
    inc cr_y
    dec cr_n
    bne .r
    rts

!zone gotoxy
gotoxy                      ; cursor (cx,cy) -> screen and colour pointers
    ldx cy
    lda rowlo,x
    clc
    adc cx
    sta sp_lo
    sta cp_lo
    lda rowhi,x
    adc #0
    sta sp_hi
    clc
    adc #$d4                ; colour RAM = screen RAM + $d400
    sta cp_hi
    rts

!zone putc
putc                        ; A = ASCII char, written at cursor, cursor moves right
    cmp #'a'
    bcc .u
    cmp #'z'+1
    bcs .u
    sec
    sbc #96                 ; a-z -> screen codes 1-26
    jmp .put
.u
    cmp #'@'
    bne .put
    lda #0
.put
    ora rev
    ldy #0
    sta (sp_lo),y
    lda ccol
    sta (cp_lo),y
    inc sp_lo
    bne +
    inc sp_hi
+   inc cp_lo
    bne +
    inc cp_hi
+   inc cx
    rts

!zone puts
puts                        ; A=lo Y=hi of a 0-terminated string
    sta str_lo
    sty str_hi
    lda #0
    sta ps_i
.l
    ldy ps_i
    lda (str_lo),y
    beq .e
    jsr putc
    inc ps_i
    bne .l
    inc str_hi
    jmp .l
.e
    rts

!zone put_name
put_name                    ; A = element index
    tax
    lda name_lo,x
    ldy name_hi,x
    jmp puts

!zone put_sym
put_sym                     ; both symbol characters (cells are 2 wide)
    asl
    tax
    lda el_sym+1,x
    pha
    lda el_sym,x
    jsr putc
    pla
    jmp putc

!zone put_sym_t
put_sym_t                   ; symbol without the trailing blank
    asl
    tax
    lda el_sym+1,x
    pha
    lda el_sym,x
    jsr putc
    pla
    cmp #' '
    beq .e
    jsr putc
.e
    rts

!zone put_cat
put_cat                     ; A = family index
    tax
    lda cat_lo,x
    ldy cat_hi,x
    jmp puts

!zone put_num
put_num                     ; A = 0..255, no leading zeros
    sta pn_v
    lda #0
    sta pn_flag
    lda pn_v
    cmp #100
    bcc .tens
    sec
    sbc #100
    sta pn_v
    lda #'1'
    jsr putc
    inc pn_flag
.tens
    ldy #0
    lda pn_v
.tl
    cmp #10
    bcc .td
    sbc #10
    iny
    jmp .tl
.td
    sta pn_v
    tya
    bne .showt
    lda pn_flag
    beq .ones
.showt
    tya
    clc
    adc #'0'
    jsr putc
.ones
    lda pn_v
    clc
    adc #'0'
    jmp putc

; element names are stored back to back (0-terminated); build a pointer table
!zone build_names
build_names
    lda #<el_names
    sta tp_lo
    lda #>el_names
    sta tp_hi
    ldx #0
.n
    lda tp_lo
    sta name_lo,x
    lda tp_hi
    sta name_hi,x
    ldy #0
.s
    lda (tp_lo),y
    beq .z
    iny
    bne .s
.z
    iny                     ; step over the 0
    tya
    clc
    adc tp_lo
    sta tp_lo
    bcc +
    inc tp_hi
+   inx
    cpx #N_ELEM
    bne .n
    rts

; ============================================================
;  INPUT / RANDOM / SOUND
; ============================================================
!zone getkey
getkey
.w
    jsr GETIN
    beq .w
    rts

!zone wait_key
wait_key
.f
    jsr GETIN               ; flush stale keys
    bne .f
.w
    jsr GETIN
    beq .w
    rts

!zone rnd_n
rnd_n                       ; A = n (1..128) -> A = random 0..n-1
    sta rn_n
    sec
    sbc #1
    sta rn_m
    lsr                     ; m |= m>>1, m>>2, m>>4  -> all-ones mask
    ora rn_m
    sta rn_m
    lsr
    lsr
    ora rn_m
    sta rn_m
    lsr
    lsr
    lsr
    lsr
    ora rn_m
    sta rn_m
.try
    jsr rnd
    and rn_m
    cmp rn_n
    bcs .try
    rts

rnd                         ; SID voice-3 noise mixed with the jiffy clock
    lda $d41b
    eor $a2
    eor $a1
    rts

!zone wait
wait                        ; A = jiffies (1/60 s), safe across the $a2 wrap
    sta wait_cnt
    lda $a2
    sta wait_start
.l
    lda $a2
    sec
    sbc wait_start
    cmp wait_cnt
    bcc .l
    rts

init_sid
    lda #0
    ldx #24
-   sta $d400,x
    dex
    bpl -
    lda #$0f
    sta $d418
    lda #$09
    sta $d405
    lda #$f0
    sta $d406
    lda #$ff
    sta $d40e               ; voice 3 free-running noise = RNG source
    sta $d40f
    lda #$80
    sta $d412
    rts

sfx_ok
    lda #$30
    sta $d401
    lda #$11
    sta $d404
    lda #6
    jsr wait
    lda #$10
    sta $d404
    rts

sfx_bad
    lda #$05
    sta $d401
    lda #$21
    sta $d404
    lda #14
    jsr wait
    lda #$20
    sta $d404
    rts

; ============================================================
;  DATA
; ============================================================
qcount      !byte 10,20,30
cat_col     !byte 2,8,14,3,5,13,7,4,10,15
cat_lo      !byte <c0,<c1,<c2,<c3,<c4,<c5,<c6,<c7,<c8,<c9
cat_hi      !byte >c0,>c1,>c2,>c3,>c4,>c5,>c6,>c7,>c8,>c9
c0  !text "Alkali metal",0
c1  !text "Alkaline earth",0
c2  !text "Transition metal",0
c3  !text "Post-transition",0
c4  !text "Metalloid",0
c5  !text "Nonmetal",0
c6  !text "Halogen",0
c7  !text "Noble gas",0
c8  !text "Lanthanide",0
c9  !text "Actinide",0

; screen row start addresses ($0400 + 40*row)
rowlo
    !byte 0,40,80,120,160,200,240,24,64,104,144,184,224,8,48,88
    !byte 128,168,208,248,32,72,112,152,192
rowhi
    !byte 4,4,4,4,4,4,4,5,5,5,5,5,5,6,6,6
    !byte 6,6,6,6,7,7,7,7,7

; element symbols, 2 characters each (index = atomic number - 1)
el_sym
    !text "H ","He","Li","Be","B ","C ","N ","O ","F ","Ne"
    !text "Na","Mg","Al","Si","P ","S ","Cl","Ar","K ","Ca"
    !text "Sc","Ti","V ","Cr","Mn","Fe","Co","Ni","Cu","Zn"
    !text "Ga","Ge","As","Se","Br","Kr","Rb","Sr","Y ","Zr"
    !text "Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In","Sn"
    !text "Sb","Te","I ","Xe","Cs","Ba","La","Ce","Pr","Nd"
    !text "Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb"
    !text "Lu","Hf","Ta","W ","Re","Os","Ir","Pt","Au","Hg"
    !text "Tl","Pb","Bi","Po","At","Rn","Fr","Ra","Ac","Th"
    !text "Pa","U ","Np","Pu","Am","Cm","Bk","Cf","Es","Fm"
    !text "Md","No","Lr","Rf","Db","Sg","Bh","Hs","Mt","Ds"
    !text "Rg","Cn","Nh","Fl","Mc","Lv","Ts","Og"

; table position of each element
el_col
    !byte 1,18,1,2,13,14,15,16,17,18,1,2,13,14,15,16,17,18
    !byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    !byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    !byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,3,4
    !byte 5,6,7,8,9,10,11,12,13,14,15,16,17,18,1,2,3,4
    !byte 5,6,7,8,9,10,11,12,13,14,15,16,3,4,5,6,7,8
    !byte 9,10,11,12,13,14,15,16,17,18
el_row
    !byte 1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3
    !byte 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
    !byte 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
    !byte 6,6,9,9,9,9,9,9,9,9,9,9,9,9,9,9,6,6
    !byte 6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,7,10,10
    !byte 10,10,10,10,10,10,10,10,10,10,10,10,7,7,7,7,7,7
    !byte 7,7,7,7,7,7,7,7,7,7

; family: 0 alkali, 1 alkaline earth, 2 transition, 3 post-transition,
;         4 metalloid, 5 nonmetal, 6 halogen, 7 noble gas, 8 lanthanide, 9 actinide
el_cat
    !byte 5,7,0,1,4,5,5,5,6,7,0,1,3,4,5,5,6,7
    !byte 0,1,2,2,2,2,2,2,2,2,2,2,3,4,4,5,6,7
    !byte 0,1,2,2,2,2,2,2,2,2,2,2,3,3,4,4,6,7
    !byte 0,1,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,2
    !byte 2,2,2,2,2,2,2,2,3,3,3,3,6,7,0,1,9,9
    !byte 9,9,9,9,9,9,9,9,9,9,9,9,9,2,2,2,2,2
    !byte 2,2,2,2,3,3,3,3,6,7

; element names, back to back, 0-terminated
el_names
    !text "Hydrogen",0
    !text "Helium",0
    !text "Lithium",0
    !text "Beryllium",0
    !text "Boron",0
    !text "Carbon",0
    !text "Nitrogen",0
    !text "Oxygen",0
    !text "Fluorine",0
    !text "Neon",0
    !text "Sodium",0
    !text "Magnesium",0
    !text "Aluminium",0
    !text "Silicon",0
    !text "Phosphorus",0
    !text "Sulfur",0
    !text "Chlorine",0
    !text "Argon",0
    !text "Potassium",0
    !text "Calcium",0
    !text "Scandium",0
    !text "Titanium",0
    !text "Vanadium",0
    !text "Chromium",0
    !text "Manganese",0
    !text "Iron",0
    !text "Cobalt",0
    !text "Nickel",0
    !text "Copper",0
    !text "Zinc",0
    !text "Gallium",0
    !text "Germanium",0
    !text "Arsenic",0
    !text "Selenium",0
    !text "Bromine",0
    !text "Krypton",0
    !text "Rubidium",0
    !text "Strontium",0
    !text "Yttrium",0
    !text "Zirconium",0
    !text "Niobium",0
    !text "Molybdenum",0
    !text "Technetium",0
    !text "Ruthenium",0
    !text "Rhodium",0
    !text "Palladium",0
    !text "Silver",0
    !text "Cadmium",0
    !text "Indium",0
    !text "Tin",0
    !text "Antimony",0
    !text "Tellurium",0
    !text "Iodine",0
    !text "Xenon",0
    !text "Caesium",0
    !text "Barium",0
    !text "Lanthanum",0
    !text "Cerium",0
    !text "Praseodymium",0
    !text "Neodymium",0
    !text "Promethium",0
    !text "Samarium",0
    !text "Europium",0
    !text "Gadolinium",0
    !text "Terbium",0
    !text "Dysprosium",0
    !text "Holmium",0
    !text "Erbium",0
    !text "Thulium",0
    !text "Ytterbium",0
    !text "Lutetium",0
    !text "Hafnium",0
    !text "Tantalum",0
    !text "Tungsten",0
    !text "Rhenium",0
    !text "Osmium",0
    !text "Iridium",0
    !text "Platinum",0
    !text "Gold",0
    !text "Mercury",0
    !text "Thallium",0
    !text "Lead",0
    !text "Bismuth",0
    !text "Polonium",0
    !text "Astatine",0
    !text "Radon",0
    !text "Francium",0
    !text "Radium",0
    !text "Actinium",0
    !text "Thorium",0
    !text "Protactinium",0
    !text "Uranium",0
    !text "Neptunium",0
    !text "Plutonium",0
    !text "Americium",0
    !text "Curium",0
    !text "Berkelium",0
    !text "Californium",0
    !text "Einsteinium",0
    !text "Fermium",0
    !text "Mendelevium",0
    !text "Nobelium",0
    !text "Lawrencium",0
    !text "Rutherfordium",0
    !text "Dubnium",0
    !text "Seaborgium",0
    !text "Bohrium",0
    !text "Hassium",0
    !text "Meitnerium",0
    !text "Darmstadtium",0
    !text "Roentgenium",0
    !text "Copernicium",0
    !text "Nihonium",0
    !text "Flerovium",0
    !text "Moscovium",0
    !text "Livermorium",0
    !text "Tennessine",0
    !text "Oganesson",0

; ---------------- variables ----------------
cx          !byte 0
cy          !byte 0
ccol        !byte 1
rev         !byte 0
ps_i        !byte 0
dc_i        !byte 0
dc_mode     !byte 0
dt_i        !byte 0
cr_y        !byte 0
cr_n        !byte 0
li          !byte 0
oi          !byte 0
qn          !byte 10
qmode       !byte 0
qi          !byte 0
score       !byte 0
qel         !byte 0
qtype       !byte 0
cpos        !byte 0
tries       !byte 0
cd_j        !byte 0
cd_a        !byte 0
mo_i        !byte 0
pk_i        !byte 0
rn_n        !byte 0
rn_m        !byte 0
pn_v        !byte 0
pn_flag     !byte 0
po_v        !byte 0
rate        !byte 0
tmpv        !byte 0
wait_cnt    !byte 0
wait_start  !byte 0
opt         !byte $ff,$ff,$ff
hiscore     !byte 0,0,0
qlist       !fill 30,0
used        !fill N_ELEM,0
name_lo     !fill N_ELEM,0
name_hi     !fill N_ELEM,0

; ---------------- texts (mixed case, written to screen RAM) --------
txt_title   !text "Periodic Table Quiz",0
txt_intro   !text "Test your knowledge of the elements!",0
txt_choose  !text "Choose a mode:",0
txt_sp2     !text "  ",0
txt_qhigh   !text " questions   high score: ",0
txt_quitline !text "Q  quit to BASIC",0

txt_q       !text "Question ",0
txt_of      !text "/",0
txt_score   !text "   Score: ",0
txt_high    !text "   High: ",0
txt_qm      !text "?",0
txt_q0a     !text "What is the chemical symbol of",0
txt_q1a     !text "Which element has the symbol",0
txt_q2a     !text "What is the atomic number of",0
txt_q3a     !text "To which family does",0
txt_q3b     !text " belong?",0
txt_q4a     !text "Which element is hidden behind ?? in",0
txt_q4b     !text "the periodic table above?",0
txt_correct !text "Correct! You score one point.",0
txt_wrong   !text "Wrong!",0
txt_answer  !text "The correct answer is: ",0
txt_cont    !text "Press a key to continue",0

txt_fin     !text "Quiz finished!",0
txt_mode    !text "Mode: ",0
txt_questions !text " questions",0
txt_yours   !text "Your score: ",0
txt_slash   !text " / ",0
txt_r1      !text "Excellent! You are a true chemist!",0
txt_r2      !text "Very good! Almost perfect.",0
txt_r3      !text "Not bad. Keep studying!",0
txt_r4      !text "Keep practising - you will get there.",0
txt_newhi   !text "NEW HIGH SCORE for this mode!",0
txt_hs      !text "High score for this mode: ",0
