.include    "address_map_arm.s" 
.include    "interrupt_ID.s" 

/* ********************************************************************************
 * This program demonstrates use of interrupts with assembly language code.
 * The program responds to interrupts from the pushbutton KEY port in the FPGA.
 *
 * The interrupt service routine for the pushbutton KEYs indicates which KEY has
 * been pressed on the LED display.
      
 This code is from "interupt_example.s", as provided by Altera.
 ********************************************************************************/

.section    .vectors, "ax" 

            B       _start                  // reset vector
            B       SERVICE_UND             // undefined instruction vector
            B       SERVICE_SVC             // software interrrupt vector
            B       SERVICE_ABT_INST        // aborted prefetch vector
            B       SERVICE_ABT_DATA        // aborted data vector
.word       0 // unused vector
            B       SERVICE_IRQ             // IRQ interrupt vector
            B       SERVICE_FIQ             // FIQ interrupt vector

.text  
.global count_global
      count_global: .fill 1,4,0x0
.global     _start 
_start:

/* Set up stack pointers for IRQ and SVC processor modes */
            MOV     R1, #0b11010010         // interrupts masked, MODE = IRQ
            MSR     CPSR_c, R1              // change to IRQ mode
            LDR     SP, =A9_ONCHIP_END - 3  // set IRQ stack to top of A9 onchip memory
/* Change to SVC (supervisor) mode with interrupts disabled */
            MOV     R1, #0b11010011         // interrupts masked, MODE = SVC
            MSR     CPSR, R1                // change to supervisor mode
            LDR     SP, =DDR_END - 3        // set SVC stack to top of DDR3 memory

            BL      CONFIG_GIC             // configure the ARM generic interrupt controller

                                            // write to the pushbutton KEY interrupt mask register
            LDR     R0, =KEY_BASE           // pushbutton KEY base address
            MOV     R1, #0xF               // set interrupt mask bits
            STR     R1, [R0, #0x8]          // interrupt mask register is (base + 8)

                                            // enable IRQ interrupts in the processor
            MOV     R0, #0b01010011         // IRQ unmasked, MODE = SVC
            MSR     CPSR_c, R0              

//ADDED code to congigure the timer (referenced from DE1-SoC_Computer.pdf): 
            LDR R2, =0xFFFEC600 // MPCore private timer base address
            LDR R3, =100000000 // timeout = 1/(200 MHz) x 100×10 ∧ 6 = 0.5 sec
            STR R3, [R2] // write to timer load register
            MOV R3, #0b111 // set bits: I = 1,  A = 1, enable = 1, and prescaler is 0.
            STR R3, [R2, #0x8] // write to timer control register
            MSR CPSR_c, R0 

IDLE:                                       
            B       IDLE                    // main program simply idles

/* Define the exception service routines */

/*--- Undefined instructions --------------------------------------------------*/
SERVICE_UND:                                
            B       SERVICE_UND             

/*--- Software interrupts -----------------------------------------------------*/
SERVICE_SVC:                                
            B       SERVICE_SVC             

/*--- Aborted data reads ------------------------------------------------------*/
SERVICE_ABT_DATA:                           
            B       SERVICE_ABT_DATA        

/*--- Aborted instruction fetch -----------------------------------------------*/
SERVICE_ABT_INST:                           
            B       SERVICE_ABT_INST        

/*--- IRQ ---------------------------------------------------------------------*/
SERVICE_IRQ:                                
            PUSH    {R0-R7, LR}             

/* Read the ICCIAR from the CPU interface */
            LDR     R4, =MPCORE_GIC_CPUIF   
            LDR     R5, [R4, #ICCIAR]       // read from ICCIAR

//ADDED to check for timer interupt
            CMP   R5, #MPCORE_PRIV_TIMER_IRQ
            BNE   FPGA_IRQ1_HANDLER //if not timer interrupt, check key interrupt

TIMER_ISR:          
            LDR   R6, =count_global
            LDR   R7, [R6]  //load global variable
            ADD   R7, R7, #1 //increment by 1
            STR   R7, [R6] //store new value
      //DISPLAY ON LEDs       
            LDR   R8, =LED_BASE // base address of LED display
            STR   R7, [R8] // display value on red LEDs
            B EXIT_IRQ
                

FPGA_IRQ1_HANDLER:                          
            CMP     R5, #KEYS_IRQ   

UNEXPECTED: BNE     TIMER_ISR             // if not recognized, stop here
            BL      KEY_ISR      


EXIT_IRQ:                                   
/* Write to the End of Interrupt Register (ICCEOIR) */
            STR     R5, [R4, #ICCEOIR]      // write to ICCEOIR

            POP     {R0-R7, LR}             
            SUBS    PC, LR, #4              

/*--- FIQ ---------------------------------------------------------------------*/
SERVICE_FIQ:                                
            B       SERVICE_FIQ             

.end         
