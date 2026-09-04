`timescale 1ns / 1ps

module TOP_TB;

    // =====================================================
    // Parámetros
    // =====================================================

    localparam NSW     = 8;
    localparam NB_DATA = 8;
    localparam NLED    = 8;

    // Opcodes extendidos a 8 bits porque TOP usa OP_reg[7:0]
    localparam ADD = 8'b00100000;
    localparam SUB = 8'b00100010;
    localparam AND = 8'b00100100;
    localparam OR  = 8'b00100101;
    localparam XOR = 8'b00100110;
    localparam SRA = 8'b00000011;
    localparam SRL = 8'b00000010;
    localparam NOR = 8'b00100111;


    // =====================================================
    // Entradas al DUT
    // =====================================================

    reg CLK;
    reg [NSW-1:0] SW;

    reg BTN_A;
    reg BTN_B;
    reg BTN_OP;


    // =====================================================
    // Salidas del DUT
    // =====================================================

    wire [NLED-1:0] LED;


    // =====================================================
    // Variables utilizadas por el testbench
    // =====================================================

    reg [NB_DATA-1:0] random_A;
    reg [NB_DATA-1:0] random_B;
    reg [7:0] random_OP;

    reg [NB_DATA-1:0] expected;

    integer i;
    integer errors;
    integer op_index;


    // =====================================================
    // Instancia del TOP
    // =====================================================

    TOP dut (
        .CLK(CLK),
        .SW(SW),
        .BTN_A(BTN_A),
        .BTN_B(BTN_B),
        .BTN_OP(BTN_OP),
        .LED(LED)
    );


    // =====================================================
    // Generación de clock
    //
    // Periodo = 10 ns -> 100 MHz
    // Igual al clock de la Basys 3
    // =====================================================

    initial begin
        CLK = 0;
    end

    always #5 CLK = ~CLK;


    // =====================================================
    // Función que calcula el resultado esperado
    // =====================================================

    function [7:0] calculate_expected;

        input [7:0] A;
        input [7:0] B;
        input [7:0] OP;

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
                    calculate_expected = 8'b00000000;

            endcase

        end

    endfunction


    // =====================================================
    // Task para cargar A
    // =====================================================

    task load_A;

        input [7:0] value;

        begin

            SW = value;

            // Se activa antes del flanco positivo
            BTN_A = 1'b1;

            @(posedge CLK);

            #1;

            BTN_A = 1'b0;

        end

    endtask


    // =====================================================
    // Task para cargar B
    // =====================================================

    task load_B;

        input [7:0] value;

        begin

            SW = value;

            BTN_B = 1'b1;

            @(posedge CLK);

            #1;

            BTN_B = 1'b0;

        end

    endtask


    // =====================================================
    // Task para cargar opcode
    // =====================================================

    task load_OP;

        input [7:0] value;

        begin

            SW = value;

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

        // Estado inicial de las entradas
        SW     = 0;

        BTN_A  = 0;
        BTN_B  = 0;
        BTN_OP = 0;

        errors = 0;


        // Esperamos un poco antes de comenzar
        #20;


        // =================================================
        // 1000 pruebas con entradas aleatorias
        // =================================================

        for (i = 0; i < 1000; i = i + 1) begin

            // Generación de operandos aleatorios
            random_A = $random;
            random_B = $random;


            // Selección aleatoria de operación
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
            // Simulación del uso real de la Basys 3
            // ---------------------------------------------

            // Colocar A en switches y pulsar BTN_A
            load_A(random_A);

            // Colocar B en switches y pulsar BTN_B
            load_B(random_B);

            // Colocar opcode en switches y pulsar BTN_OP
            load_OP(random_OP);


            // Calcular resultado que debería entregar la ALU
            expected =
                calculate_expected(
                    random_A,
                    random_B,
                    random_OP
                );


            // Dar tiempo para propagación combinacional
            #1;


            // ---------------------------------------------
            // Chequeo automático
            // ---------------------------------------------

            if (LED !== expected) begin

                $display(
                    "ERROR Test %0d: A=%h B=%h OP=%b LED=%h Expected=%h",
                    i,
                    random_A,
                    random_B,
                    random_OP,
                    LED,
                    expected
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
