print("fio-spi-fifo-v1")

--Configure the T7's SPI bus
MB.W(5000, 0, 0)  --CS, EIO0
MB.W(5001, 0, 1)  --CLK, EIO1
MB.W(5002, 0, 2)  --MISO, EIO2
MB.W(5003, 0, 3)  --MOSI, EIO3

MB.W(5004, 0, 0)  --Mode
MB.W(5005, 0, 0)  --Speed
MB.W(5006, 0, 1)  --Options, enable CS
MB.W(5009, 0, 1)  --Num Bytes to Tx/Rx

-- SPI Slave device config data
configBytes = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00}

--SPI Slave device acquisition write data
acqStateWriteData = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00}

--SPI Slave device bytes to Read
acqStateNumBytesToRead = 9
dummyReadData = {}
for i in acqStateNumBytesToRead do
  dummyWriteDataForRead[i]=0
end

--Configure FIFO system

--Configure the state machine's state
--0: Initializing
--1: Waiting for a trigger: Reads FIO0, if:
--   1, switches to acquisition state.
--   0, remains in waiting for trigger state.
--2: Acquisition state.  
--   Reads the FIO0 line a second time to make sure its still high to de-bounce the IO line.
--   Performs SPI COM & saving data to FIFO.
--   Also updates secondary IO line
--3: Wait for Trigger Re-Set. Reads FIO0, if: 
--   1, Remains in the wait for trigger re-set state.
--   0, Switches to the waiting for trigger state.
state=1

INIT_STATE = 0
WAIT_TRIG_STATE = 1
ACQ_STATE = 2
TRIG_RESET_STATE = 3

FIO1_INIT_STATE = 0
MB.W(2001,0,FIO1_INIT_STATE)

while true do
if state == INIT_STATE then
  -- Initializing
  -- 1. Send 6 bytes of data to a SPI slave device.
  MB.W(5009,0,table.getn(acqStartWriteData))
  MB.WA(5010,99,table.getn(configBytes),configBytes)
  MB.W(5007,0,1)

  --Start waiting for a trigger to occur.
  state = WAIT_TRIG_STATE
elseif state = WAIT_TRIG_STATE then
  -- Waiting for trigger
  local fio0 = MB.R(2000, 0)
  if fio0 == 1 then
    --Switch to the acquisitino state.
    state = ACQ_STATE
  end
elseif state = ACQ_STATE then
  -- Acquire data from SPI device
  -- 1. Send 6 bytes of data to a SPI slave device.
  MB.W(5009,0,table.getn(acqStartWriteData))
  MB.WA(5010,99,table.getn(acqStartWriteData),acqStartWriteData)
  MB.W(5007,0,1)

  -- 2. Read 9 bytes of data from a SPI slave device.
  MB.W(5009,0,acqStateNumBytesToRead)
  MB.WA(5010,99,acqStateNumBytesToRead,dummyWriteDataForRead)
  MB.W(5007,0,1)
  local readData = MB.RA(5050, 99)

  -- TODO: 3. Save collected data to FIFO, 
  -- 4. Toggle FIO1 line to indicate that a trigger occured.
  MB.W(2001,0,1)
  MB.W(2001,0,FIO1_INIT_STATE)

  --Wait for the trigger signal to re-set.
  state = TRIG_RESET_STATE
elseif state = TRIG_RESET_STATE then
  -- Wait for trigger to re-set
  local fio0 = MB.R(2000, 0)
  if fio0 == 0 then
    --Start waiting for a trigger to occur.
    state = WAIT_TRIG_STATE
  end
else 
  print("In Else case.......", state)
end
