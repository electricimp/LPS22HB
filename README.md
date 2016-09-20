# Driver for the LPS25H Air Pressure / Temperature Sensor

The [LPS22HB](http://www.st.com/content/ccc/resource/technical/document/datasheet/bf/c1/4f/23/61/17/44/8a/DM00140895.pdf/files/DM00140895.pdf/jcr:content/translations/en.DM00140895.pdf) is a MEMS absolute pressure sensor. This sensor features a large functional range (260-1260hPa) and internal averaging for improved precision.

The LPS22HB can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

**To add this library to your project, add** `#require "LPS22HB.class.nut:1.0.0"` **to the top of your device code**

## Hardware

To use the LPS22HB, connect its I&sup2;C interface to any of your imp module’s I&sup2;C buses. To learn which pins provide I&sup2;C functionality, see the [imp pin mux](https://electricimp.com/docs/hardware/imp/pinmux/) in the Electric Imp Dev Center.

The LPS22HB interrupt pin behavior may be configured through this class, but the corresponding imp pin and associated callback are not configured or managed through this class. To use the interrupt pin:

- Connect the LPS22HB INT_DRDY pin to an imp GPIO pin
- Configure the imp pin connected to INT_DRDY as a *DIGITAL_IN* with your desired callback function
- Use the methods in this class to configure the interrupt behavior as required

[add curcuit pic here]

## Class Usage

### Constructor: LPS22HB(*impI2cBus[, i2cAddress]*)

The constructor takes two arguments to instantiate the class: a pre-configured I&sup2;C bus and the sensor’s I&sup2;C address in 8-bit form. The I&sup2;C address is optional and defaults to `0xB8`.

```squirrel
// Non-default 8-bit I2C Address for LPS25H (SA0 pulled high)
const LPS25H_ADDR = 0xBA;

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
pressureSensor <- LPS25H(hardware.i2c89, LPS25H_ADDR);
```

### Reset

The LPS22HB is not automatically reset when constructed so that Electric Imp applications can use the device through sleep/wake cycles without it losing state. To reset the device to a known state, call the *softReset()* method:

```squirrel
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
pressureSensor <- LPS25H(hardware.i2c89);
pressureSensor.softReset();
```

## Class Methods

### read([*callback*])

The **read()** method returns a pressure reading in hPa and a temperature reading in °C. The reading result is in the form of a table with the fields *pressure* and *temperature*. If an error occurs during the reading the pressure and temperature fields will be null, and the reading table will contain an additional field, *err*, with a description of the error.

If a callback parameter is provided, the reading executes asynchronously, and the results table will be passed to the supplied function as the only parameter. If no callback is provided, the method blocks until the reading has been taken and then returns the results table.

#### Asynchronous example

```squirrel
pressureSensor.read(function(result) {
    if ("err" in result) {
        server.error("An Error Occurred: " + result.err);
    } else {
        server.log(format("Current Pressure: %0.2f hPa, Current Temperature: %0.2f °C", result.pressure, result.temperature));
    }
});
```

#### Synchronous example

```squirrel
function hpaToHg(hpa) {
    return (1.0 * hpa) / 33.8638866667;
}

local result = pressureSensor.read();

if ("err" in result) {
    server.error("An Error Occurred: " + result.err);
} else {
    server.log(format("Current Pressure: %0.2f in. Hg", hpaToHg(result.pressure));
}
```

### setMode(*mode[, dataRate]*)

The LPS22HB can be configured in two different reading modes: *LPS22HB_MODE.ONE_SHOT* or  *LPS22HB_MODE.CONTINUOUS*. In *LPS22HB_MODE.ONE_SHOT* a reading will only be taken only when the *read()* method is called, this is the default mode.  In *LPS22HB_MODE.CONTINUOUS* a reading frequecy must also be selected using the *dataRate* parameter and when the *read()* method is called the latest reading will be returned.

The *dataRate* parameter sets the output data rate (ODR) of the pressure sensor in Hz. The nearest supported data rate less than or equal to the requested rate will be set and returned by *setMode()*. Supported data rates are 0 (one shot configuration), 1, 10, 25, 50 and 75Hz.

```squirrel
local dataRate =pressureSensor.setMode(LPS22HB_MODE.CONTINUOUS, 25);
server.log(dataRate);
```

### getMode()

Returns the LPS22HB_MODE of the pressure sensor.

```squirrel
local mode = pressureSensor.getMode();
if (mode == LPS22HB_MODE.ONE_SHOT) {
    server.log("In one shot mode");
}
if (mode == LPS22HB_MODE.CONTINUOUS) {
    server.log("In continuous mode with a data rate of " + pressureSensor.getDataRate() + "Hz");
}
```

### getDataRate()

Returns the output data rate (ODR) of the pressure sensor in Hz.

```squirrel
local dataRate = pressureSensor.getDataRate();
server.log(dataRate);
```

### enableLowCurrentMode(*enabled*)

The *enableLowCurrentMode()* method sets the sensor's resolution mode and takes one required parameter: a boolean *enabled*.  When *enabled* is `true` the low current mode is enabled and the device minimizes the current consumption.  When *enabled* is `false` the device is optimized to lower the noise.  This mode should only be changed when the device is in power down mode (ie configured in one-shot mode and not taking a reading).

```squirrel
pressureSensor.enableLowCurrentMode(true);
```

### configureDifferentalPressureMode(*mode, enabled*)

The *configureDifferentalPressureMode()* method takes two required parameters: a class constant *mode* and a boolean *enabled*.  There are two differental pressure modes: *LPS22HB_MODE.AUTO_ZERO* or *LPS22HB_MODE.AUTO_RIF_P*.  After enabling either mode the first reading taken will be used to set a reference pressure.  In *LPS22HB_MODE.AUTO_ZERO* mode both the pressure value used for interrupt generation and the pressure reading returned by the *read()* method will then be determided by subtracting the *referencePressure* from the measured pressure. In LPS22HB_MODE.AUTO_RIF_P mode the pressure value used for interrupt generation will be determided by subtracting the *referencePressure* from the measured pressure, however the pressure value returned by the *read()* method will be the measured pressure.  If sensor is configured in one-shot mode the *configureDifferentalPressureMode()* will take a reading to set the reference pressure.  If the sensor is configured in continuous mode you must wait one reading cycle before the reference pressure is set.

Once a mode is enabled the sensor will remain in that mode until it is disabled.  To disable select the mode and pass `false` into the *enabled* parameter.

```squirrel
// Set mode to one-shot
pressureSensor.setMode(LPS22HB_MODE.ONE_SHOT);
// Take a reading
local reading = pressureSensor.read();
server.log(reading.pressure);
// Enable Auto Zero
server.log("----------------------------");
server.log("Enable Auto Zero mode");
pressureSensor.configureDifferentalPressureMode(LPS22HB_MODE.AUTO_ZERO, true);
// Take a couple readings in Auto Zero mode
reading = pressureSensor.read();
server.log(reading.pressure);
imp.sleep(5);
reading = pressureSensor.read();
server.log(reading.pressure);
// Disable Auto Zero mode
server.log("----------------------------");
server.log("Disabling Auto Zero mode")
press.configureDifferentalPressureMode(LPS22HB_MODE.AUTO_ZERO, false);
// Take a reading
reading = pressureSensor.read();
server.log(reading.pressure);
```

### configureDataReadyInterrupt(*enable[, options]*)

This method configures the interrupt pin driver for a data ready interrupt. The device starts with this disabled by default.

####Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| *enable* | boolean | N/A | Set `true` to enable the interrupt pin. |
| *options* | Bitfield | 0x00 | Configuration options combined with the bitwise OR operator. See the ‘Options’ table below. |

#### Options

| Option Constant | Description |
| --- | --- |
| *INT_PIN_ACTIVELOW* | Interrupt pin is active-high by default. Use to set interrupt to active-low. |
| *INT_PIN_OPENDRAIN* | Interrupt pin driver push-pull by default.Use to set interrupt to open-drain. |
| *INT_LATCH* | Interrupt latching mode is disabled by default. Use to enable interrupt latching mode. To clear a latched interrupt pin call *getInterruptSrc()* |

```squirrel
// Enable interrupt, configure as push-pull, active-high.
pressureSensor.configureDataReadyInterrupt(true);
```

### configureThresholdInterrupt(*enable[, threshold][, options]*)

This method configures the interrupt pin driver for an interrupt based on a threshold event. The device starts with this disabled by default.

####Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| *enable* | boolean | N/A | Set `true` to enable the interrupt pin. |
| *threshold* | Integer | null | Interrupts are generated on pressure events. The threshold is expressed in hectopascals (hPa). |
| *options* | Bitfield | 0x00 | Configuration options combined with the bitwise OR operator. See the ‘Options’ table below. |

#### Options

| Option Constant | Description |
| --- | --- |
| *INT_PIN_ACTIVELOW* | Interrupt pin is active-high by default. Use to set interrupt to active-low. |
| *INT_PIN_OPENDRAIN* | Interrupt pin driver push-pull by default.Use to set interrupt to open-drain. |
| *INT_LATCH* | Interrupt latching mode is disabled by default. Use to enable interrupt latching mode. To clear a latched interrupt pin call *getInterruptSrc()* |
| *INT_LOW_PRESSURE* | Interrupt is disabled by default. Use to enable interrupt when pressure below threshold |
| *INT_HIGH_PRESSURE* | Interrupt is disabled by default. Use to enable interrupt when pressure above threshold |

```squirrel
// Enable interrupt, configure as push-pull, active-high, latched. Fire interrupt if pressure > 10 hPa
pressureSensor.configureThresholdInterrupt(true, 10, LPS25H.INT_LATCH | LPS25H.INT_HIGH_PRESSURE);
```

```squirrel
// Enable interrupt, configure as open-drain, active-low, latched. Fire interrupt if pressure < -20 hPa
pressureSensor.configureThresholdInterrupt(true, 20, LPS25H.INT_PIN_ACTIVELOW | LPS25H.INT_PIN_OPENDRAIN | LPS25H.INT_LATCH | LPS25H.INT_LOW_PRESSURE);
```

### getInterruptSrc()

Use the *getInterruptSrc()* method to determine what caused an interrupt, and clear latched interrupt. This method returns a table with three keys to provide information about which interrupts are active.

| key | Description |
| --- | --- |
| *int_active* | `true` if an interrupt is currently active or latched |
| *high_pressure* | `true` if the active or latched interrupt was due to a high pressure event |
| *low_pressure* | `true` if the active or latched interrupt was due to a low pressure event |

```squirrel
// Check the interrupt source and clear the latched interrupt
local intSrc = pressureSensor.getInterruptSrc();
if (intSrc.int_active) {
    // interrupt is active
    if (intSrc.high_pressure) server.log("High Pressure Interrupt Occurred");
    if (intSrc.low_pressure) server.log("Low Pressure Interrupt Occurred");
} else {
    server.log("No Interrupts Active");
}
```

### softReset()

Reset the LPS25H from software.

```squirrel
pressureSensor.softReset();
```

### getDeviceID()

Returns the value of the device ID register, `0xBD`.

## License

The LPS22HB library is licensed under the [MIT License](./LICENSE).