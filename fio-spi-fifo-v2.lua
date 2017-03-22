print("fio-spi-fifo-v1")

--Configure the T7's SPI bus
MB.W(5000, 0, 8)  --CS, EIO0
MB.W(5001, 0, 9)  --CLK, EIO1
MB.W(5002, 0, 2)  --MISO, FIO2
MB.W(5003, 0, 11)  --MOSI, EIO3

MB.W(5004, 0, 0)  --Mode
MB.W(5005, 0, 65530)  --Speed
MB.W(5006, 0, 1)  --Options, enable CS
MB.W(5009, 0, 1)  --Num Bytes to Tx/Rx

-- SPI Slave device config data
configBytesSampleSpeed = {0x50, 0x02}
configBytesEnableXYZ   = {0x48, 0x04}
configBytesEnable      = {0x5A, 0x00}

--SPI Slave device acquisition write data
acqStateWriteData = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00}

--SPI Slave device bytes to Read
acqStateNumBytesToRead = 4
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

-- FIO1 initial state.
FIO1_INIT_STATE = 0
MB.W(2001,0,FIO1_INIT_STATE)

-- Debugging print-out controls.
oldState = 0
numBetweenStatusUpdate = 50000
curNoPrintCount = 0

----------------------------------------------------------------------------------------------------------------
print("Enable the high speed counter on CIO0")
local count = 0
-- Enable CounterA on DIO16/CIO0
MB.W(44032, 1, 0) -- disable the DIO16_EF_ENABLE
MB.W(44132, 1, 7) -- Configure to be a high speed counter DIO16_EF_INDEX
MB.W(44032, 1, 1) -- enable the DIO16_EF_ENABLE

if clearCount then
  -- Read DIO16_EF_READ_A_AND_RESET to return the current count & reset the value
  count = MB.R(3132, 1)
else
  -- read DIO16_EF_READ_A to return the current count
  count = MB.R(3032, 1)
end
----------------------------------------------------------------------------------------------------------------


function spiWrite (data)
  MB.W(5009,0,table.getn(data))
  MB.WA(5010,99,table.getn(data),data)
  MB.W(5007,0,1)
end
function spiRead (numBytes, fakeData)
  MB.W(5009,0,numBytes)
  MB.WA(5010,99,numBytes,fakeData)
  MB.W(5007,0,1)
  return MB.RA(5050, 99, numBytes)
end



local count = 0
local lastCount = 0

 -- Initializing
-- 1. Perform initial configuration
spiWrite(configBytesSampleSpeed)
spiWrite(configBytesEnableXYZ)
spiWrite(configBytesEnable)

while true do
  count = MB.R(3132, 1)
  if count > 1 then
    -- Indicate that we missed an SPI value.
    MB.W(2003,0,1)
    MB.W(2003,0,0)
  end

  if count > 0 then
    -- Toggle FIO1 line to indicate that a trigger occured and is being processed.
    MB.W(2001,0,1)
    -- perform a triggered SPI read.
    -- Acquire data from SPI device
    -- 1. Send 6 bytes of data to a SPI slave device.
    -- MB.W(5009,0,table.getn(acqStateWriteData))
    -- MB.WA(5010,99,table.getn(acqStateWriteData),acqStateWriteData)
    -- MB.W(5007,0,1)
    -- spiWrite(acqStateWriteData) -- SPI write is not performed in customer's code.
  
    -- 2. Read 9 bytes of data from a SPI slave device.
    -- MB.W(5009,0,acqStateNumBytesToRead)
    -- MB.WA(5010,99,acqStateNumBytesToRead,dummyWriteDataForRead)
    -- MB.W(5007,0,1)
    -- local readData = MB.RA(5050, 99, acqStateNumBytesToRead)
    local readData = spiRead(acqStateNumBytesToRead, dummyWriteDataForRead)
    val = bit.bor(bit.lshift(readData[2],12),bit.lshift(readData[3],4),bit.rshift(readData[4],4))

    -- print("Read SPI Data", table.getn(readData))
    
  
    -- 3. Save collected data to FIFO
    numBytesFIFO0 = MB.R(47910, 1)
    if (numBytesFIFO0 < numBytesAllocFIFO0) then
      -- MB.WA(47000,0,table.getn(readData)-0,readData)
      -- for i=1,table.getn(readData) do
      --   local newVal = readData[i]
      --   MB.W(47000,0,newVal)
      -- end
      MB.W(47010,1,val)
      numBytesFIFO0 = MB.R(47910, 1)
      -- print("Num bytes in buffer", numBytesFIFO0)
      -- Indicate that data was written.
      MB.W(2008,0,1)
      MB.W(2008,0,0)
    else
      -- print ("FIFO0 buffer is full.")
      -- Indicate that the buffer is full.
      MB.W(2000,0,1)
      MB.W(2000,0,0)
    end
    
    -- 4. Toggle FIO1 line to indicate that a trigger occured and it has finished being processed.
    MB.W(2001,0,FIO1_INIT_STATE)
  end
end
