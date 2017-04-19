// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


// Tests written for an Imp 001 Explorer kit

class BasicTestCase extends ImpTestCase {

    _press = null;
    _int = null;

    // Initialize sensor
    function setUp() {
        // imp001 explorer kit i2c bus
        local i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        // imp001 explorer kit i2c address
        local addr = 0xB8;

        _int = hardware.pin1;

        _press = LPS22HB(i2c, addr);
        _press.softReset();

        return "Sensor initialized";
    }

    function testSensorDevID() {
        local id = _press.getDeviceID();
        this.assertEqual(0xB1, id, "Device id doen't match datasheet");
    }

    function testLowCurrentMode() {
        _press.enableLowCurrentMode(true);
        // no good way to test so just check register
        local val = _press._getReg(LPS22HB.RES_CONF);
        // mask other bits
        val = val & 0x01;
        // bit 0 should be 1
        this.assertEqual(0x01, val, "Register not set");

        _press.enableLowCurrentMode(false);
        local val = _press._getReg(LPS22HB.RES_CONF);
        // no good way to test so just check register
        local val = _press._getReg(LPS22HB.RES_CONF);
        // mask other bits
        val = val & 0x01;
        // bit 0 should be 1
        this.assertEqual(0x00, val, "Register not set");
    }

    function testDifferentialPressureMode() {
        // set up interrupt and test each mode
    }

    // this is an issue - constants not defined!!
    function testLowPassFilter() {
        // _press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
        // _press.configureLowPassFilter(LPS22HB.LPF_BANDWIDTH_ODR_9);
        // local val = _getReg(CTRL_REG1);
        // check bits
    }

    function testDataReadyInterrupt() {
        local result_1, result_2;
        return Promise(function(resolve, reject) {
            _int.configure(DIGITAL_IN_WAKEUP, function() {
                if (_int.read() != 0) {
                    result_2 = _press.read();
                    this.info(format("Last Pressure: %0.4f hPa, last Temperature: %0.4f °C", result_1.pressure, result_1.temperature));
                    this.info(format("New Pressure: %0.4f hPa, new Temperature: %0.4f °C", result_2.pressure, result_2.temperature));
                    // readings should not be identical
                    this.assertTrue( (result_2.pressure !=  result_1.pressure) || (result_2.temperature !=  result_1.temperature), "Data ready interrupt not triggerd as expected");
                    _press.configureDataReadyInterrupt(false);
                    resolve();
                }
            }.bindenv(this))
            _press.setMode(LPS22HB_MODE.CONTINUOUS, 1);
            _press.getInterruptSrc();
            result_1 = _press.read();
            _press.configureDataReadyInterrupt(true);
        }.bindenv(this))
    }

    function testThresholdInterrupt() {
        return Promise(function(resolve, reject) {
            _int.configure(DIGITAL_IN_WAKEUP, function() {
                if (_int.read() != 0) {
                    local result = _press.getInterruptSrc();
                    this.assertTrue(result.int_active, "Threshold interrupt triggered, int_active val not expected")
                    this.assertTrue(result.low_pressure, "Threshold interrupt triggered, low_pressure val not expected");
                    this.assertTrue(!result.high_pressure, "Threshold interrupt triggered, high_pressure val not expected");
                    _press.configureThresholdInterrupt(false);
                    resolve();
                }
            }.bindenv(this))
            _press.setMode(LPS22HB_MODE.CONTINUOUS, 1);
            _press.getInterruptSrc();
            local reading = _press.read();
            _press.configureThresholdInterrupt(true, (reading.pressure - 5), LPS22HB.INT_LATCH | LPS22HB.INT_HIGH_PRESSURE);
        }.bindenv(this))
    }

    function testSyncRead() {
        _press.setMode(LPS22HB_MODE.ONE_SHOT);
        local result = _press.read();
        this.assertTrue( !("err" in result) );
        this.info(format("Current Pressure: %0.2f hPa, Current Temperature: %0.2f °C", result.pressure, result.temperature));
        this.assertTrue(result.temperature > 0 && result.temperature < 50, "Temperature reading not within acceptable bounds");
        this.assertTrue(result.pressure > 950 && result.pressure < 1100, "Pressure reading not within acceptable bounds");
    }

    function testAsyncRead() {
        _press.setMode(LPS22HB_MODE.ONE_SHOT);
        return Promise(function(resolve, reject) {
            _press.read(function(result) {
                if ("err" in result) {
                    reject(result.err);
                } else {
                    this.info(format("Current Pressure: %0.2f hPa, Current Temperature: %0.2f °C", result.pressure, result.temperature));
                    this.assertTrue(result.temperature > 0 && result.temperature < 50, "Temperature reading not within acceptable bounds");
                    this.assertTrue(result.pressure > 950 && result.pressure < 1100, "Pressure reading not within acceptable bounds");
                    resolve("Pressure and Temperature readings with in acceptable bounds");
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function testReset() {
        // change a setting
        // reset and check that setting is changes back to default
    }

    // Test mode
    function testSetGetMode() {
        local dataRate = _press.setMode(LPS22HB_MODE.ONE_SHOT);
        this.assertEqual(0, dataRate, "Set mode return value not equal to expected data rate");
        local mode = _press.getMode();
        this.assertEqual(LPS22HB_MODE.ONE_SHOT, mode, "Get mode return value not equal to expected mode");
    }

    // Test DataRate
    function testGetSupportedDataRate() {
        local supportedDataRate = 25;
        local dataRate = _press.setMode(LPS22HB_MODE.CONTINUOUS, supportedDataRate);
        this.assertEqual(supportedDataRate, dataRate, "Set mode return value not equal to expected data rate");
        local getDR = _press.getDataRate();
        this.assertEqual(supportedDataRate, getDR, "Get data rate not equal to expected data rate");
    }

    // Test DataRate
    function testGetUnupportedDataRate() {
        local unsupportedDataRate = 30;
        local expectedDR = 25;
        local dataRate = _press.setMode(LPS22HB_MODE.CONTINUOUS, unsupportedDataRate);
        this.assertEqual(expectedDR, dataRate, "Set mode return value not equal to expected data rate");
        local getDR = _press.getDataRate();
        this.assertEqual(expectedDR, getDR, "Get data rate not equal to expected data rate");
    }

    function tearDown() {
        _press.softReset();
    }

}
