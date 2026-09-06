`timescale 1ns / 1ps

module TOP_TB;

    // =====================================================
    // Parámetros
    // =====================================================

    localparam NSW     = 8;
    localparam NB_DATA = 8;
    localparam NB_OP   = 6;
    localparam NLED    = 10;


    // =====================================================
    // Opcodes
    // =====================================================

    localparam [NB_OP-1:0] ADD = 6'b100000;
    localparam [NB_OP-1:0] SUB = 6'b100010;
    localparam [NB_OP-1:0] AND = 6'b100100;
    localparam [NB_OP-1:0] OR  = 6'b100101;
    localparam [NB_OP-1:0] XOR = 6'b100110;
    localparam [NB_OP-1:0] SRA = 6'b000011;
    localparam [NB_OP-1:0] SRL = 6'b000010;
    localparam [NB_OP-1:0] NOR = 6'b100111;


    // =====================================================
    // Entradas al DUT
    // =====================================================

    reg CLK;
    reg [NSW-1:0] SW;

    reg BTN_A;
    reg BTN_B;
    reg BTN_OP;
    reg BTN_RESET;


    // =====================================================
    // Salidas del DUT
    // =====================================================

    wire [NLED-1:0] LED;


    // =====================================================
    // Variables utilizadas por el testbench
    // =====================================================

    reg [NB_DATA-1:0] random_A;
    reg [NB_DATA-1:0] random_B;
    reg [NB_OP-1:0] random_OP;

    reg [NB_DATA-1:0] expected;
    reg expected_zero;
    reg expected_carry;

    integer i;
    integer errors;
    integer op_index;


    // =====================================================
    // Instancia del TOP
    // =====================================================

    TOP #(
        .NSW(NSW),
        .NB_DATA(NB_DATA),
        .NB_OP(NB_OP),
        .NLED(NLED)
    ) dut (
        .CLK(CLK),
        .SW(SW),
        .BTN_A(BTN_A),
        .BTN_B(BTN_B),
        .BTN_OP(BTN_OP),
        .BTN_RESET(BTN_RESET),
        .LED(LED)
    );


    // =====================================================
    // Generación del clock
    //
    // Periodo = 10 ns
    // Frecuencia = 100 MHz
    // =====================================================

    initial begin
        CLK = 1'b0;
    end

    always #5 CLK = ~CLK;


    // =====================================================
    // Función: resultado esperado
    // =====================================================

    function [NB_DATA-1:0] calculate_expected;

        input [NB_DATA-1:0] A;
        input [NB_DATA-1:0] B;
        input [NB_OP-1:0] OP;

        begin

            case (OP)

                ADD: calculate_expected = A + B;
                SUB: calculate_expected = A - B;
                AND: calculate_expected = A & B;
                OR : calculate_expected = A | B;
                XOR: calculate_expected = A ^ B;
                SRA: calculate_expected = $signed(A) >>> B;
                SRL: calculate_expected = A >> B;
                NOR: calculate_expected = ~(A | B);

                default:
                    calculate_expected = {NB_DATA{1'b0}};

            endcase

        end

    endfunction


    // =====================================================
    // Función: carry / borrow esperado
    // =====================================================

    function calculate_expected_carry;

        input [NB_DATA-1:0] A;
        input [NB_DATA-1:0] B;
        input [NB_OP-1:0] OP;

        reg [NB_DATA:0] extended_result;

        begin

            extended_result = {(NB_DATA + 1){1'b0}};

            case (OP)

                ADD: begin
                    extended_result = {1'b0, A} + {1'b0, B};
                    calculate_expected_carry = extended_result[NB_DATA];
                end

                SUB:
                    calculate_expected_carry = (A < B);

                default:
                    calculate_expected_carry = 1'b0;

            endcase

        end

    endfunction


    // =====================================================
    // Task: cargar A
    // =====================================================

    task load_A;

        input [NB_DATA-1:0] value;

        begin

            SW = value;
            BTN_A = 1'b1;

            @(posedge CLK);

            #1;

            BTN_A = 1'b0;

        end

    endtask


    // =====================================================
    // Task: cargar B
    // =====================================================

    task load_B;

        input [NB_DATA-1:0] value;

        begin

            SW = value;
            BTN_B = 1'b1;

            @(posedge CLK);

            #1;

            BTN_B = 1'b0;

        end

    endtask


    // =====================================================
    // Task: cargar opcode
    // =====================================================

    task load_OP;

        input [NB_OP-1:0] value;

        begin

            SW = {{(NSW-NB_OP){1'b0}}, value};
            BTN_OP = 1'b1;

            @(posedge CLK);

            #1;

            BTN_OP = 1'b0;

        end

    endtask


    // =====================================================
    // Test principal
    // =====================================================

    initial begin

        // -------------------------------------------------
        // Inicialización
        // -------------------------------------------------

        SW = {NSW{1'b0}};

        BTN_A = 1'b0;
        BTN_B = 1'b0;
        BTN_OP = 1'b0;
        BTN_RESET = 1'b0;

        errors = 0;


        // -------------------------------------------------
        // Reset inicial
        // -------------------------------------------------

        BTN_RESET = 1'b1;

        @(posedge CLK);

        #1;

        BTN_RESET = 1'b0;


        // Esperar antes de comenzar las pruebas
        #10;


        // =================================================
        // 1000 pruebas aleatorias
        // =================================================

        for (i = 0; i < 1000; i = i + 1) begin

            // ---------------------------------------------
            // Generación aleatoria de operandos
            // ---------------------------------------------

            random_A = $random;
            random_B = $random;


            // ---------------------------------------------
            // Selección aleatoria de operación
            // ---------------------------------------------

            op_index = $random;

            if (op_index < 0)
                op_index = -op_index;

            op_index = op_index % 8;


            case (op_index)

                0: random_OP = ADD;
                1: random_OP = SUB;
                2: random_OP = AND;
                3: random_OP = OR;
                4: random_OP = XOR;
                5: random_OP = SRA;
                6: random_OP = SRL;
                7: random_OP = NOR;

                default:
                    random_OP = ADD;

            endcase


            // ---------------------------------------------
            // Simulación de la carga de operandos
            // ---------------------------------------------

            load_A(random_A);
            load_B(random_B);
            load_OP(random_OP);


            // ---------------------------------------------
            // Cálculo del resultado esperado
            // ---------------------------------------------

            expected =
                calculate_expected(
                    random_A,
                    random_B,
                    random_OP
                );

            expected_zero =
                (expected == {NB_DATA{1'b0}});

            expected_carry =
                calculate_expected_carry(
                    random_A,
                    random_B,
                    random_OP
                );


            // Dar tiempo para propagación combinacional
            #1;


            // ---------------------------------------------
            // Chequeo automático
            // ---------------------------------------------

            if (
                LED[NB_DATA-1:0] !== expected ||
                LED[8] !== expected_zero ||
                LED[9] !== expected_carry
            ) begin

                $display(
                    "ERROR Test %0d: A=%h B=%h OP=%b Result=%h Expected=%h Zero=%b ExpectedZero=%b Carry=%b ExpectedCarry=%b",
                    i,
                    random_A,
                    random_B,
                    random_OP,
                    LED[NB_DATA-1:0],
                    expected,
                    LED[8],
                    expected_zero,
                    LED[9],
                    expected_carry
                );

                errors = errors + 1;

            end

        end


        // =================================================
        // Resultado final
        // =================================================

        $display("");
        $display("======================================");
        $display("        RESULTADO DEL TEST");
        $display("======================================");

        if (errors == 0) begin

            $display("TEST PASSED");
            $display("1000 pruebas realizadas correctamente.");

        end
        else begin

            $display("TEST FAILED");
            $display("Cantidad de errores: %0d", errors);

        end

        $display("======================================");
        $display("");


        $finish;

    end

endmodule
