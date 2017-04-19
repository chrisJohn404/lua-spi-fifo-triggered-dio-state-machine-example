# SPI, FIFO Queues, and DIO Triggered State Machine example

This is an example for how to configure a T7 with a Lua Script to recieve a control pulse on FIO0 (for example, a 1kHz square wave) and respond to each pulse by reading data from a SPI bus data source and control a secondary DIO line accordingly.

To provide a brief explanation of the hardware involved in this example, a T7 is being connected to a digital control line that uses 3.3V logic and creating square wave pulses at a rate of 1kHz.  The trigger condition is defined as when the digital I/O line switches from low (0V) to high (3.3V).  Each of these pulses instruct the T7 to write 6 bytes of data out to a SPI slave device.  After doing this, 9 bytes of data need to then be read from the SPI slave device.

This data will be saved to the data queue that is accesable through the USER_RAM_FIFOx set of registers.  In this example, we will be using the USER_RAM_FIFO0_DATA_U16 which is a first-in-first-out data queue.  The T7's lua script will be collecting data from SPI and saving it directly to the FIFO for a secondary application to then collect and interpret.

## Going Further:
Data can also be interpreted by the T7 and saved into other FIFO data types.  The T7 makes the data types U16, U32, I32, F32 available for saving data into the queues.  Instead of saving SPI data directly into the UINT16 buffer, data can be interpreted or packed into other data types.

## Getting Started
To use this example you need to have 1 T7 that preferably has an active ethernet connection so that the device can have more than one program using it.  USB connections only support one active connection.  Ethernet connections support two.  WiFi supports one.

The Lua script that needs to be loaded onto the T7 is called "fio-spi-fifo-v1.lua".  Open this file in Kipling through the Lua Script Debugger tab and press the "run script" button.  After the script has been started and is working properly, press the "save script to flash" button.  Your T7 is now programmed with the example script and if the device gets power cycled it will properly restart and start running the script again.

After running the script, open LabVIEW and run the fifo-reading.vi.  For the convenience of our Windows users, there is also an included .exe that can be executed.

## Basic required Lua Knowledge
Here are some of the basic functions that will be used in this example.  
* MB.R, Modbus Read, (address, data type):

  To read the state of the FIO0 line on a T7 you call: `MB.R(2000,0)`.

* MB.W, Modbus Write, (address, data type, value):

  To write the state of an FIO line or execute SPI functions you call: `MB.W(2001,0, 1)` (Write a 1 to FIO1), `MB.W(5007,0, 1)` (Write a 1 to SPI_GO).  

* MB.RA, Modbus Read Array, (address, data type, num values):

  To read 9 bytes of data that was read during an SPI transaction data needs to be read from the SPI_DATA_RX register shich is done by calling: `MB.RA(5050, 99, 9)`.

* MB.WA, Modbus Write Array, (address, data type, num values, table):

  6 bytes of data can be written to an SPI slave device by calling the following three functions:
  1. Defining there to be 6 bytes of data being written: `MB.W(5009,0,6)`.
  2. Writing 6 bytes of data into the SPI data tx buffer: `MB.WA(5010,99,6,{0,0,0,0,0,0})`
  3. Instructing the SPI transaction to start: `MB.W(5007,0,1)`.

For more information and a complete list of functions implemented and exposed by the T7 go to the [Scripting section](https://labjack.com/support/datasheets/t7/scripting) of the [T7 Datasheet](https://labjack.com/support/datasheets/t7).  To learn more about the T7's SPI functionality go to the [SPI section](https://labjack.com/support/datasheets/t7/digital-io/spi) of the T7 Datasheet.

## SPI Basic Information
Understanding the basics of SPI is important in this example.  Essentially, SPI data is transfered between a master and a slave device at a given rate (clock speed).  The SPI clock speed for a T7 is defined by the "SPI_SPEED_THROTTLE" register (address 5005, UINT16).  When using SPI, you define the number of bytes that need to be sent from a master device or read from a slave device and then clock that number of bits of data to/from the slave device.  On a T7, you define the number of bytes using the SPI_NUM_BYTES register (address 5009, UINT16).  You then define what data needs to be written to the slave device using the SPI_DATA_TX (address 5010, buffer, BYTE) register.  You then write a 1 to the SPI_GO (address 5007, UINT16) register.  SPI data is then transfered between the master and slave device asynchronously.  Asynchronously meaning that data is being sent from the master device to the slave device at the same time as data is being read from the slave device by the master.  After the SPI data transfer finishes, the data that was read from the slave device during the last transaction will be available in the SPI_DATA_RX (address 5050, buffer, BYTE) register.  

More information about SPI with the T7 can be found in the SPI section of the T7 Datasheet.  
https://labjack.com/support/datasheets/t7/digital-io/spi

## FIFO Basic information
The T7 has 4 available first-in first-out queues that can be used to transfer data from a T7 to a PC.  Keep in mind that data can only be removed from the buffer once.  If read function calls fail, data will likely get lost.  

The size of the four FIFOs are allocated in memory by calling the USER_RAM_FIFO#(0:3)_NUM_BYTES_IN_FIFO registers.  Their base address is 47910 and are of type UINT32.  Data can be filled into and read out of the queues by calling their respective USER_RAM_FIFO[endpoint num]_DATA_[type] register.  The T7 makes the data types: U16, U32, I32, F32 available as queues.  Perform modbus reads to the registers to remove values from the queues and perform modbus writes to fill them. 

The number of bytes currently in the FIFO can be read by the USER_RAM_FIFO#(0:3)_NUM_BYTES_IN_FIFO registers.  The FIFOs can be forcefully emptied/flushed by calling the USER_RAM_FIFO#(0:3)_EMPTY registers.  

More information about the FIFO registers can be found in the Scripting section of the T7 Datasheet.  
https://labjack.com/support/datasheets/t7/scripting

## Changelog:
### V1
v1 of example code & application uses a state machine checking the FIO line for toggles to then go into a state where the SPI bus was read.  The data is buffered using uint16 data types.

### V2
v2 of example code & application require the input-trigger to go to CIO0 which is configured as a high-speed counter and the lua script reads the counter's value to see if it had any counts.  v2 of the lua script also sets several IO lines for debugging purposes.  Here is a list of debugging pins:
* CIO0 - Input Pulse, 1k square wave results in some SPI data being missed.  950Hz was working well (3/21/2017, FW1.0216, LJM1.1403).
* FIO1 - When the IO line is high, SPI data is being sampled.  
* FIO3 - This is set when multiple triggers have passed between querying for the last data set.  This indicates that there is missing data.
* FIO0 - is toggled when the data que gets filled up and the latest data that was collected wasn't saved.
* DIO0 - is toggled when data is saved to the queue successfully.
