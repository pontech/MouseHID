// 20140316
#include <chipKITUSBDevice.h>
#include "DetectEdge.h"


// include HID for HID declarations; not part of the standard USB Device library include
#include "chipKITUSBHIDFunction.h"

/************************************************************************/
/*									*/
/*	CustomHID.pde	-- Demonstrates a Custom HID USB Device         */
/*		    using the chipKIT Max32 and chipKIT Network Shield	*/
/*									*/
/************************************************************************/
/*	Author: 	Keith Vogel 					*/
/*	Copyright 2011, Digilent Inc.					*/
/************************************************************************/
/*
  This sketch is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This sketch is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this sketch; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/
/************************************************************************/
/*  Module Description: 						*/
/*									*/
/*	This library is explicity targeting the chipKIT Max32    	*/
/*	PIC32MX795F512L MCU using chipKIT Network Shield 	        */
/*	It exposes the Microchip USB Device Library                     */		
/*	for use with MPIDE sketches					*/
/*									*/
/*	The PC should run the GenericHIDSimpleDemo.exe as		*/
/*	provided by the Microchip MAL                                   */
/*      "USB Device - HID - Custom Demos" example.      	        */
/*	                                                         	*/
/*	Windows should already have the needed drivers installed.	*/
/*									*/
/************************************************************************/
/*  Revision History:							*/
/*									*/
/*	8/08/2011(KeithV): Created					*/
/*									*/
/************************************************************************/

// forward reference for the USB constructor
static boolean MY_USER_USB_CALLBACK_EVENT_HANDLER(USB_EVENT event, void *pdata, word size);

// the size of our EP 1 HID buffer
#define USB_EP_SIZE         64          // size or our EP 1 i/o buffers.
#define TOGGLE_LED          0x80        // command from PC to toggle LED state
#define GET_LED_STATE       0x81        // command from PC to get LED state
#define LED                 81         // pin for the LED
#define MIN_BLINK_LOOP_CNT  80000       // the min number of times we must loop before changing the state of the LED while blinking
#define MAX_BLINK_MULT      8           // The max number of times (MAX_BLINK_MULT * MIN_BLINK_LOOP_CNT) through the loop before changing the state of the LED while blinking

USB_HANDLE hHost2Device = 0;		// Handle to the HOST OUT buffer
byte rgHost2Device[USB_EP_SIZE];	// the OUT buffer which is always relative to the HOST, so this is really an in buffer to us

USB_HANDLE hDevice2Host = 0;		// Handle to the HOST IN buffer
uint8_t rgDevice2Host[USB_EP_SIZE];	// the IN buffer which is always relative to the HOST, so this is really an out buffer to us

// some bookkeeping variables for the host.
uint8_t idle_rate;
uint8_t active_protocol;   // [0] Boot Protocol [1] Report Protocol

// Create an instance of the USB device
USBDevice usb(MY_USER_USB_CALLBACK_EVENT_HANDLER);	// specify the callback routine
// USBDevice usb(NULL);		// use default callback routine
// USBDevice usb;		// use default callback routine

#define LButtonPin C0IO0
#define MButtonPin C0IO1
#define RButtonPin C0IO2
#define LUpButtonPin C0IO3
#define MUpButtonPin C1IO0
#define RUpButtonPin C1IO1
#define WheelUpPin C1IO2
#define WheelDnPin C1IO3
#define XposPin C2IO0
#define XnegPin C2IO1
#define YposPin C2IO2
#define YnegPin C2IO3

DetectEdge LButtonEdge(LButtonPin,true,10);
DetectEdge MButtonEdge(MButtonPin,true,10);
DetectEdge RButtonEdge(RButtonPin,true,10);
DetectEdge LUpButtonEdge(LUpButtonPin,true,10);
DetectEdge MUpButtonEdge(MUpButtonPin,true,10);
DetectEdge RUpButtonEdge(RUpButtonPin,true,10);
unsigned char ButtonsDown = 0;
bool ButtonsDownUpdated = false;

void setup() 
{
  // Enable the serial port for some debugging messages
  Serial1.begin(115200);
  Serial1.println("call init");

  // This starts the attachement of this USB device to the host.
  // true indicates that we want to wait until we are configured.
  usb.InitializeSystem(true);
  // Serial1.println("return from init");
  
  // wait until we get configured
  // this should already be done becasue we said to wait until configured on InitializeSystem
  while(usb.GetDeviceState() < CONFIGURED_STATE);
	
  //Serial1.print("Configured, usbOut = ");      
  //Serial1.println((int) hHost2Device, HEX); 

  // set the LED as an output parameter
  pinMode(LED, OUTPUT);
  pinMode(LButtonPin,INPUT);
  pinMode(MButtonPin,INPUT);
  pinMode(RButtonPin,INPUT);
  pinMode(LUpButtonPin,INPUT);
  pinMode(MUpButtonPin,INPUT);
  pinMode(RUpButtonPin,INPUT);
  pinMode(WheelUpPin,INPUT);
  pinMode(WheelDnPin,INPUT);
  pinMode(XposPin,INPUT);
  pinMode(XnegPin,INPUT);
  pinMode(YposPin,INPUT);
  pinMode(YnegPin,INPUT);
}

void loop() {
  ButtonsDown = 0;
  LButtonEdge.scan();
  MButtonEdge.scan();
  RButtonEdge.scan();
  LUpButtonEdge.scan();
  MUpButtonEdge.scan();
  RUpButtonEdge.scan();
  
  if(LButtonEdge.rising())
  {
    ButtonsDown |= 0x01;
    ButtonsDownUpdated = true;
  }
  if(LButtonEdge.falling())
  {
    ButtonsDown &= ~0x01;
    ButtonsDownUpdated = true;
  }
  if(MButtonEdge.rising())
  {
    ButtonsDown |= 0x04;
    ButtonsDownUpdated = true;
  }
  if(MButtonEdge.falling())
  {
    ButtonsDown &= ~0x04;
    ButtonsDownUpdated = true;
  }
  if(RButtonEdge.rising())
  {
    ButtonsDown |= 0x02;
    ButtonsDownUpdated = true;
  }
  if(RButtonEdge.falling())
  {
    ButtonsDown &= ~0x02;
    ButtonsDownUpdated = true;
  }
  if(LUpButtonEdge.rising())
  {
    ButtonsDown |= 0x08;
    ButtonsDownUpdated = true;
  }
  if(LUpButtonEdge.falling())
  {
    ButtonsDown &= ~0x08;
    ButtonsDownUpdated = true;
  }
  if(MUpButtonEdge.rising())
  {
    ButtonsDown |= 0x20;
    ButtonsDownUpdated = true;
  }
  if(MUpButtonEdge.falling())
  {
    ButtonsDown &= ~0x20;
    ButtonsDownUpdated = true;
  }
  if(RUpButtonEdge.rising())
  {
    ButtonsDown |= 0x10;
    ButtonsDownUpdated = true;
  }
  if(RUpButtonEdge.falling())
  {
    ButtonsDown &= ~0x10;
    ButtonsDownUpdated = true;
  }
  if(digitalRead(WheelUpPin)==LOW)
  {
    rgDevice2Host[3] = 1; // wheel
    ButtonsDownUpdated = true;
  }
  if(digitalRead(WheelDnPin)==LOW)
  {
    rgDevice2Host[3] = -1; // wheel
    ButtonsDownUpdated = true;
  }
  if(digitalRead(XposPin)==LOW)
  {
    rgDevice2Host[1] = 4; // wheel
    ButtonsDownUpdated = true;
  }
  if(digitalRead(XnegPin)==LOW)
  {
    rgDevice2Host[1] = -4; // wheel
    ButtonsDownUpdated = true;
  }
  if(digitalRead(YposPin)==LOW)
  {
    rgDevice2Host[2] = 4; // wheel
    ButtonsDownUpdated = true;
  }
  if(digitalRead(YnegPin)==LOW)
  {
    rgDevice2Host[2] = -4; // wheel
    ButtonsDownUpdated = true;
 }
  if(ButtonsDownUpdated)
  {
    rgDevice2Host[0] = ButtonsDown; //((unsigned char)1)<<serial_command[6]; // Mouse buttons
    //rgDevice2Host[1] = 0; // x
    //rgDevice2Host[2] = 0; // y
    //rgDevice2Host[3] = 0; // wheel
    rgDevice2Host[4] = 0x3A; // Not sure what this is for
    
    // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
    if(!usb.HandleBusy(hDevice2Host))
    {
      hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 4); //USB_EP_SIZE);	// write out our data
    }
    rgDevice2Host[1] = 0; // x
    rgDevice2Host[2] = 0; // y
    rgDevice2Host[3] = 0; // wheel
    ButtonsDownUpdated = false;
  }
  static int ledValue = LOW;

  static int ledBlink = LOW;
  static boolean fBlink = true;
  static int  cBlink = MIN_BLINK_LOOP_CNT;
  static int cBlinkMult = 1;
 
  static char serial_command[20];
  
  // Simple Serial parser
  if (receive_function(serial_command,sizeof(serial_command)))
  {
    if (strcmp(serial_command, "reset") == 0) //compare the received string to the string "reset"
    {
      Reset();
    }
    else if (strcmp(serial_command, "reboot") == 0)
    {
      Reboot();
    }
    else if (strcmp(serial_command, "movex") == 0)
    {
      rgDevice2Host[0] = 0; // Mouse buttons
      rgDevice2Host[1] = 10; // x
      rgDevice2Host[2] = 0; // y
      rgDevice2Host[3] = 0; // wheel
      rgDevice2Host[4] = 0x3A; // Not sure what this is for
      
      // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
      if(!usb.HandleBusy(hDevice2Host))
      {
        hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 3); //USB_EP_SIZE);	// write out our data
      }
    }
    else if (strcmp(serial_command, "movey") == 0)
    {
      rgDevice2Host[0] = 0; // Mouse buttons
      rgDevice2Host[1] = 0; // x
      rgDevice2Host[2] = 10; // y
      rgDevice2Host[3] = 0; // wheel
      rgDevice2Host[4] = 0x3A; // Not sure what this is for
      
      // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
      if(!usb.HandleBusy(hDevice2Host))
      {
        hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 3); //USB_EP_SIZE);	// write out our data
      }
    }
    else if (strcmp(serial_command, "buttonup") == 0)
    {
      rgDevice2Host[0] = 0x01; //((unsigned char)1)<<serial_command[6]; // Mouse buttons
      rgDevice2Host[1] = 1; // x
      rgDevice2Host[2] = 1; // y
      rgDevice2Host[3] = 0; // wheel
      rgDevice2Host[4] = 0x3A; // Not sure what this is for
      
      // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
      if(!usb.HandleBusy(hDevice2Host))
      {
        hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 3); //USB_EP_SIZE);	// write out our data
      }
    }
    else if (strcmp(serial_command, "buttondn") == 0)
    {
      rgDevice2Host[0] = (unsigned char)0x00; //((unsigned char)1)<<serial_command[6]; // Mouse buttons
      rgDevice2Host[1] = 1; // x
      rgDevice2Host[2] = 1; // y
      rgDevice2Host[3] = 0; // wheel
      rgDevice2Host[4] = 0x3A; // Not sure what this is for
      
      // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
      if(!usb.HandleBusy(hDevice2Host))
      {
        hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 3); //USB_EP_SIZE);	// write out our data
      }
    }
    else //none of the ifs above were true
    {
      Serial1.println("Command not recognized");
    }
  }
#ifdef GONE
  // we are armed and waiting for something to come from the Host on EP 1
  // when the handle is no longer busy, that means some data came in.      
  if(!usb.HandleBusy(hHost2Device))
  {
    // debug prints to see what command came in.
    Serial1.print("code: ");  
    Serial1.println(rgHost2Device[0], HEX);

    // It is our sketch convention that the first byte from the PC
    // is an opcode command to tell use what to do.
    switch(rgHost2Device[0])
    {
      // the toggle LED command
      case TOGGLE_LED:
        // toggle the LED value
        ledValue ^= HIGH;

        // write the new LED value to the LED
        digitalWrite(LED, ledValue);

        // The first time we toggle the LED, we no longer blink.
        fBlink = false;
          break;

        // The Microchip PC application is looking for a push button state, but there is no pushbutton
        // on the chipKIT board, so instead, return the state of the LED
      case GET_LED_STATE:
        rgDevice2Host[0] = GET_LED_STATE;		//Echo back to the host PC the command sent to use so the PC knows we are responding to the get LED request
        rgDevice2Host[1] = ledValue ^ HIGH;		// return the LED state; actually the inverse as this is tricking the default Microchip application as pushbuttons are high when OFF with pullup resistors

        // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
        if(!usb.HandleBusy(hDevice2Host))
        {
          hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, USB_EP_SIZE);	// write out our data
        }
        break;
      default:
        break;
    }

    // arm for the next read, it will busy until we get another command on EP 1
    hHost2Device = usb.GenRead(HID_EP, rgHost2Device, USB_EP_SIZE);  
  }   
#endif

  // blink if we never hit the toggle button on the PC
  if(fBlink && cBlink-- == 0)
  {
    // toggle the blink value
    ledBlink ^= HIGH;
    digitalWrite(LED, ledBlink);  // write out the new value

    // we want an irregular blink so we know the chipKIT is not in the bootloader loop which also blinks the LED.
    // the irregular blink tells us that our code is running and waiting for a command from the PC
    cBlinkMult = cBlinkMult == MAX_BLINK_MULT ? 1 : ++cBlinkMult;
    cBlink = cBlinkMult * MIN_BLINK_LOOP_CNT;
  }
}

/********************************************************************
   The following code was, for the most part,
   lifted from Microchip sources and must comply with 
   the Microchip licensing requirements

    Software License Agreement:
    
    The software supplied herewith by Microchip Technology Incorporated
    (the “Company”) for its PIC® Microcontroller is intended and
    supplied to you, the Company’s customer, for use solely and
    exclusively on Microchip PIC Microcontroller products. The
    software is owned by the Company and/or its supplier, and is
    protected under applicable copyright laws. All rights are reserved.
    Any use in violation of the foregoing restrictions may subject the
    user to criminal sanctions under applicable laws, as well as to
    civil liability for the breach of the terms and conditions of this
    license.
    
    THIS SOFTWARE IS PROVIDED IN AN “AS IS” CONDITION. NO WARRANTIES,
    WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, BUT NOT LIMITED
    TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    PARTICULAR PURPOSE APPLY TO THIS SOFTWARE. THE COMPANY SHALL NOT,
    IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL OR
    CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.
*/

/********************************************************************
	Function:
		void USBCheckHIDRequest(void)
		
 	Summary:
 		This routine handles HID specific request that happen on EP0.  
        This function should be called from the USBCBCheckOtherReq() call back 
        function whenever implementing a HID device.

 	Description:
 		This routine handles HID specific request that happen on EP0.  These
        include, but are not limited to, requests for the HID report 
        descriptors.  This function should be called from the 
        USBCBCheckOtherReq() call back function whenever using an HID device.	

        Typical Usage:
        <code>
        void USBCBCheckOtherReq(void)
        {
            //Since the stack didn't handle the request I need to check
            //  my class drivers to see if it is for them
            USBCheckHIDRequest();
        }
        </code>
		
	PreCondition:
		None
		
	Parameters:
		None
		
	Return Values:
		None
		
	Remarks:
		None
 
 *******************************************************************/

void USBCheckHIDRequest(void)
{
  if(SetupPkt.Recipient != USB_SETUP_RECIPIENT_INTERFACE_BITFIELD)
  {
    Serial1.println("SetupPkt.Recipient != USB_SETUP_RECIPIENT_INTERFACE_BITFIELD");
    return;
  }
  if(SetupPkt.bIntfID != HID_INTF_ID)
  {
    Serial1.println("SetupPkt.bIntfID != HID_INTF_ID");
    return;
  }
    
    /*
     * There are two standard requests that hid.c may support.
     * 1. GET_DSC(DSC_HID,DSC_RPT,DSC_PHY);
     * 2. SET_DSC(DSC_HID,DSC_RPT,DSC_PHY);
     */
  if(SetupPkt.bRequest == USB_REQUEST_GET_DESCRIPTOR)
  {
    Serial1.println("SetupPkt.bRequest == USB_REQUEST_GET_DESCRIPTOR");
    switch(SetupPkt.bDescriptorType)
    {
      case DSC_HID: //HID Descriptor
        Serial1.println("SetupPkt.bDescriptorType == DSC_HID");
        if(usb.GetDeviceState() >= CONFIGURED_STATE)
        {
          //18 is a magic number.  It is the offset from start of the configuration descriptor to the start of the HID descriptor.
          usb.EP0SendROMPtr((uint8_t*)&configDescriptor1 + 18,sizeof(USB_HID_DSC)+3,USB_EP0_INCLUDE_ZERO);
        }
        break;
      case DSC_RPT:  //Report Descriptor
        Serial1.println("SetupPkt.bDescriptorType == DSC_RPT");
        Serial1.print("SetupPkt.wIndex = ");
        Serial1.println((int) SetupPkt.wIndex, HEX);
        if(usb.GetDeviceState() >= CONFIGURED_STATE)
        {
          switch(SetupPkt.wIndex) // figure out which interface the requested report descriptor
          {
            case 0: // interface 0
              usb.EP0SendROMPtr((uint8_t*)ReportDescriptorMouse,sizeof(ReportDescriptorMouse),USB_EP0_INCLUDE_ZERO);
              break;
            case 1: // interface 1
              //usb.EP0SendROMPtr((uint8_t*)&ReportDescriptorKeyboard,sizeof(ReportDescriptorKeyboard),USB_EP0_INCLUDE_ZERO);
              break;
          }
          //See usbcfg.h
        }
        break;
      case DSC_PHY:  //Physical Descriptor
        Serial1.println("SetupPkt.bDescriptorType == DSC_PHY");
        //Note: The below placeholder code is commented out.  HID Physical Descriptors are optional and are not used
        //in many types of HID applications.  If an application does not have a physical descriptor,
        //then the device should return STALL in response to this request (stack will do this automatically
        //if no-one claims ownership of the control transfer).
        //If an application does implement a physical descriptor, then make sure to declare
        //hid_phy01 (rom structure containing the descriptor data), and hid_phy01 (the size of the descriptors in bytes),
        //and then uncomment the below code.
        //if(USBActiveConfiguration == 1)
        //{
        //    USBEP0SendROMPtr((ROM BYTE*)&hid_phy01, sizeof(hid_phy01), USB_EP0_INCLUDE_ZERO);
        //}
        break;
      default:
        Serial1.print("SetupPkt.bDescriptorType = ");
        Serial1.println((int) SetupPkt.bDescriptorType, HEX);
        break;
    }//end switch(SetupPkt.bDescriptorType)
  }//end if(SetupPkt.bRequest == GET_DSC)
    
  if(SetupPkt.RequestType != USB_SETUP_TYPE_CLASS_BITFIELD)
  {
    Serial1.println("SetupPkt.bRequest == USB_SETUP_TYPE_CLASS_BITFIELD");
    usb.EP0Transmit(USB_EP0_NO_DATA);
    return;
  }

  switch(SetupPkt.bRequest)
  {
    case GET_REPORT:
      Serial1.println("SetupPkt.bRequest == GET_REPORT");
      #if defined USER_GET_REPORT_HANDLER
        USER_GET_REPORT_HANDLER();
      #endif
      break;
    case SET_REPORT:
      Serial1.println("SetupPkt.bRequest == SET_REPORT");
      #if defined USER_SET_REPORT_HANDLER
        USER_SET_REPORT_HANDLER();
      #endif       
      break;
    case GET_IDLE:
      Serial1.println("SetupPkt.bRequest == GET_IDLE");
      usb.EP0SendRAMPtr((uint8_t*)&idle_rate,1,USB_EP0_INCLUDE_ZERO);
      break;
    case SET_IDLE:
      Serial1.println("SetupPkt.bRequest == SET_IDLE");
      usb.EP0Transmit(USB_EP0_NO_DATA);
      idle_rate = SetupPkt.W_Value.byte.HB;
      break;
    case GET_PROTOCOL:
      Serial1.println("SetupPkt.bRequest == GET_PROTOCOL");
      usb.EP0SendRAMPtr((uint8_t*)&active_protocol,1,USB_EP0_NO_OPTIONS);
      break;
    case SET_PROTOCOL:
      Serial1.println("SetupPkt.bRequest == SET_PROTOCOL");
      usb.EP0Transmit(USB_EP0_NO_DATA);
      active_protocol = SetupPkt.W_Value.byte.LB;
      break;
    default:
       Serial1.print("SetupPkt.bRequest = ");
      Serial1.println((int) SetupPkt.bRequest, HEX);
      break;
  }//end switch(SetupPkt.bRequest)
}//end USBCheckHIDRequest

/*******************************************************************
 * Function:        BOOL MY_USER_USB_CALLBACK_EVENT_HANDLER(
 *                        USB_EVENT event, void *pdata, WORD size)
 *
 * PreCondition:    None
 *
 * Input:           USB_EVENT event - the type of event
 *                  void *pdata - pointer to the event data
 *                  WORD size - size of the event data
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        This function is called from the USB stack to
 *                  notify a user application that a USB event
 *                  occured.  This callback is in interrupt context
 *                  when the USB_INTERRUPT option is selected.
 *
 * Note:            None
 *******************************************************************/
static boolean MY_USER_USB_CALLBACK_EVENT_HANDLER(USB_EVENT event, void *pdata, word size)
{
  // initial connection up to configure will be handled by the default callback routine.
  usb.DefaultCBEventHandler(event, pdata, size);
  
  // see what is coming in on the control EP 0
  switch(event)
  {
    case EVENT_TRANSFER:
      Serial1.println("EVENT_TRANSFER");
      //Add application specific callback task or callback function here if desired.
      break;
    case EVENT_SOF:
      //Serial1.println("EVENT_SOF"); // This happens alot
      break;
    case EVENT_SUSPEND:
      Serial1.println("EVENT_SUSPEND");
      break;
    case EVENT_RESUME:
      Serial1.println("EVENT_RESUME");
      break;
    case EVENT_CONFIGURED:
      Serial1.println("EVENT_CONFIGURED");
      // Enable Endpoint 1 (HID_EP) for both input and output... 2 endpoints are used for this.
      usb.EnableEndpoint(HID_EP,USB_OUT_ENABLED|USB_IN_ENABLED|USB_HANDSHAKE_ENABLED|USB_DISALLOW_SETUP);

      // set up to wait (arm) for a command to come in on EP 1 (HID_EP) 
      rgHost2Device[0] = 0;
      hHost2Device = usb.GenRead(HID_EP, rgHost2Device, USB_EP_SIZE);
      break;
    case EVENT_SET_DESCRIPTOR:
      Serial1.println("EVENT_SET_DESCRIPTOR");
      break;
    case EVENT_EP0_REQUEST:
      Serial1.println("EVENT_EP0_REQUEST");
      // this is the handler to deal with EP 0 request
      // this is where our HID device talks to the USB Host controller   
      USBCheckHIDRequest();
      break;
    case EVENT_BUS_ERROR:
      Serial1.println("EVENT_BUS_ERROR");
      break;
    case EVENT_TRANSFER_TERMINATED:
      Serial1.println("EVENT_TRANSFER_TERMINATED");
      //Add application specific callback task or callback function here if desired.
      //The EVENT_TRANSFER_TERMINATED event occurs when the host performs a CLEAR
      //FEATURE (endpoint halt) request on an application endpoint which was 
      //previously armed (UOWN was = 1).  Here would be a good place to:
      //1.  Determine which endpoint the transaction that just got terminated was 
      //      on, by checking the handle value in the *pdata.
      //2.  Re-arm the endpoint if desired (typically would be the case for OUT 
      //      endpoints).
      break;
    default:
      Serial1.print("event = ");
      Serial1.println((int) event, HEX);
      break;
  }      
}

void Reboot()
{
  Serial1.println("Resetting board...");
  unsigned char sec;
  for( sec = 1; sec >= 1; sec-- ) {
    Serial1.print(sec,DEC);
    Serial1.println(" seconds...");
    delay(1000);
  }
  SYSKEY = 0x00000000;  //write invalid key to force lock
  SYSKEY = 0xAA996655;  //write key1 to SYSKEY
  SYSKEY = 0x556699AA;  //write key2 to SYSKEY  // OSCCON is now unlocked
  RSWRSTSET = 1; //set SWRST bit to arm reset
  unsigned int dummy;
  dummy = RSWRST; //read RSWRST register to trigger reset
  while(1); //prevent any unwanted code execution until reset occurs
}
void Reset()
{
  VIRTUAL_PROGRAM_BUTTON_TRIS = 0; //Set virtual button as output
  VIRTUAL_PROGRAM_BUTTON = 1; //push virtual button
  Reboot();
}
void Restore()
{
  VIRTUAL_PROGRAM_BUTTON_TRIS = 1; //Set virtual button as output
  VIRTUAL_PROGRAM_BUTTON = 0; //push virtual button
}

unsigned char receive_function(char* buff,unsigned char sizevar)
{
  static unsigned char ctr = 0;      //varaible to store the value of the current position in the buff array
  unsigned char ch;           //variable to store the last character received from the serial port
  if (Serial1.available() > 0) //if there are characters stored in the serial input buffer
  {
    ch = Serial1.read(); //read one character from buffer
    if (ch == '\n') return 0; // don't put new lines into the buffer
    if( ctr < sizevar) { // if the counter has not exceeded size of your buffer yet
      buff[ctr++] = ch; //add it to your buffer
    }
    if (ch == '\r') //if that character is a carriage return
    {
      buff[ctr-1] = 0; //replace the carriage return with 0 the string termination
      ctr = 0; //reset the pointer
      Serial1.print("Command["); //print a string and stay on the same line
      Serial1.print(strlen(buff),DEC);
      Serial1.print("]: "); //print a string and stay on the same line
      Serial1.println(buff); //print out the string received followed by a new line
      return 1;
    }
    else
      return 0;
  } //end serial was available
  return 0;
}


