BeagleBone Black Assembly code that initializes GPIO pins, configures INTC interrupt controller to allow IRQ, hooks and chains IRQ Interrupt Vector in the IVT then responds to IRQ. When idle, the code simply loops in a wait state.

GPIO configurations (1 input, 1 output):
* P8 Header PIN\<16\> is GPIO1_14 to the L4 Interconnect, INPUT pin generates interrupt sig\<98\> to MPU
* P8 Header PIN\<12\> is GPIO1_12, OUTPUT pin lights LED for about 1 second

This code was developed for an Interfacing with Embedded Systems class at University, not commercially.
It may be reproduced without consultation, however, if selling a product, etc. Please let me know first, (but there is nothing truly novel in here
anyway).

This code is provided with ABSOLUTLEY NO WARRANTY and I will NOT be held responsible for ANYTHING connected to or related to any issue arising from the use of this code.

That said, enjoy, and please notify me of any bugs and keep in mind that I am merely a student! I am very much still learning. Any feedback is appreciated!
