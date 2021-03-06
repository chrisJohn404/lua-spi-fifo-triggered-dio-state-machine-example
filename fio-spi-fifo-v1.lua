print("fio-spi-fifo-v1")

--Configure the T7's SPI bus
MB.W(5000, 0, 8)  --CS, EIO0
MB.W(5001, 0, 9)  --CLK, EIO1
MB.W(5002, 0, 2)  --MISO, FIO2
MB.W(5003, 0, 11)  --MOSI, EIO3

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
dummyWriteDataForRead = {}
for i=1,acqStateNumBytesToRead do
  dummyWriteDataForRead[i]=0
end

--Configure FIFO system
numReadsToSaveInFIFO0 = 10
numBytesPerSamples = 2
numBytesAllocFIFO0 = acqStateNumBytesToRead * numReadsToSaveInFIFO0 * numBytesPerSamples
MB.W(47900, 1, numBytesAllocFIFO0)
numBytesFIFO0 = MB.R(47910, 1)

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
state=0

INIT_STATE = 0
WAIT_TRIG_STATE = 1
ACQ_STATE = 2
TRIG_RESET_STATE = 3

--fio0Debouncing:
numReq = 500
curNum = 0

FIO1_INIT_STATE = 0
MB.W(2001,0,FIO1_INIT_STATE)

oldState = 0
numBetweenStatusUpdate = 50000
curNoPrintCount = 0

function spiWrite (data)
  MB.W(5009,0,table.getn(data))
  MB.WA(5010,99,table.getn(data),data)
  MB.W(5007,0,1)
end

while true do
  -- Debugging Code
  if oldState ~= state then
   print('Switching from', oldState, 'to: ', state)
   oldState = state
  else
    curNoPrintCount=curNoPrintCount+1
    if curNoPrintCount >= numBetweenStatusUpdate then
      curNoPrintCount = 0
      numBytesFIFO0 = MB.R(47910, 1)
      local numReads = numBytesFIFO0/(acqStateNumBytesToRead*numBytesPerSamples)
      print('Current State', state, 'numBytes', numBytesFIFO0, 'numReads', numReads)
    end
  end

  if state == INIT_STATE then
    -- Initializing
    -- 1. Send 6 bytes of data to a SPI slave device.
    MB.W(5009,0,table.getn(configBytes))
    MB.WA(5010,99,table.getn(configBytes),configBytes)
    MB.W(5007,0,1)
  
    --Start waiting for a trigger to occur.
    state = WAIT_TRIG_STATE
  elseif state == WAIT_TRIG_STATE then
    -- Waiting for trigger
    local fio0 = MB.R(2000, 0)
    if fio0 == 1 then
      curNum = curNum + 1
      if curNum >= numReq then
        --Switch to the acquisitino state.
        state = ACQ_STATE
      end
    else
      curNum = 0
    end
  elseif state == ACQ_STATE then
    -- Acquire data from SPI device
    -- 1. Send 6 bytes of data to a SPI slave device.
    MB.W(5009,0,table.getn(acqStateWriteData))
    MB.WA(5010,99,table.getn(acqStateWriteData),acqStateWriteData)
    MB.W(5007,0,1)
  
    -- 2. Read 9 bytes of data from a SPI slave device.
    MB.W(5009,0,acqStateNumBytesToRead)
    MB.WA(5010,99,acqStateNumBytesToRead,dummyWriteDataForRead)
    MB.W(5007,0,1)
    local readData = MB.RA(5050, 99, acqStateNumBytesToRead)
    print("Read SPI Data", table.getn(readData))
    
  
    -- 3. Save collected data to FIFO
    numBytesFIFO0 = MB.R(47910, 1)
    if (numBytesFIFO0 < numBytesAllocFIFO0) then
      -- MB.WA(47000,0,table.getn(readData)-0,readData)
      for i=1,table.getn(readData) do
        local newVal = readData[i]
        MB.W(47000,0,newVal)
      end
      numBytesFIFO0 = MB.R(47910, 1)
      print("Num bytes in buffer", numBytesFIFO0)
    else
      print ("FIFO0 buffer is full.")
    end
    
    -- 4. Toggle FIO1 line to indicate that a trigger occured.
    MB.W(2001,0,1)
    MB.W(2001,0,FIO1_INIT_STATE)
  
    --Wait for the trigger signal to re-set.
    state = TRIG_RESET_STATE
  elseif state == TRIG_RESET_STATE then
    -- Wait for trigger to re-set
    local fio0 = MB.R(2000, 0)
    
    if fio0 == 0 then
      curNum = curNum +1
      if curNum >= numReq then
        --Start waiting for a trigger to occur.
        state = WAIT_TRIG_STATE
      end
    else
      curNum = 0
    end
  else 
    print("In Else case.......", state)
  end
end
