#ifndef HIDCODE_H
#define HIDCODE_H
//#define SerialDebug

//function prototypes
void sendSerialDebugMessage(String Str);
void sendSerialDebugMessage(String Str, int val);

// forward reference for the USB constructor
static boolean MY_USER_USB_CALLBACK_EVENT_HANDLER(USB_EVENT event, void *pdata, word size);

// the size of our EP 1 HID buffer
#define USB_EP_SIZE         64          // size or our EP 1 i/o buffers.

USB_HANDLE hHost2Device = 0;		// Handle to the HOST OUT buffer
byte rgHost2Device[USB_EP_SIZE];	// the OUT buffer which is always relative to the HOST, so this is really an in buffer to us

USB_HANDLE hDevice2Host = 0;		// Handle to the HOST IN buffer
uint8_t rgDevice2Host[USB_EP_SIZE] = {0,0,0,0};	// the IN buffer which is always relative to the HOST, so this is really an out buffer to us

// some bookkeeping variables for the host.
uint8_t idle_rate;
uint8_t active_protocol;   // [0] Boot Protocol [1] Report Protocol

// Create an instance of the USB device
USBDevice usb(MY_USER_USB_CALLBACK_EVENT_HANDLER);	// specify the callback routine
// USBDevice usb(NULL);		// use default callback routine
// USBDevice usb;		// use default callback routine

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
    sendSerialDebugMessage("SetupPkt.Recipient != USB_SETUP_RECIPIENT_INTERFACE_BITFIELD");
    return;
  }
  if(SetupPkt.bIntfID != HID_INTF_ID)
  {
    sendSerialDebugMessage("SetupPkt.bIntfID != HID_INTF_ID");
    return;
  }
    
    /*
     * There are two standard requests that hid.c may support.
     * 1. GET_DSC(DSC_HID,DSC_RPT,DSC_PHY);
     * 2. SET_DSC(DSC_HID,DSC_RPT,DSC_PHY);
     */
  if(SetupPkt.bRequest == USB_REQUEST_GET_DESCRIPTOR)
  {
    sendSerialDebugMessage("SetupPkt.bRequest == USB_REQUEST_GET_DESCRIPTOR");
    switch(SetupPkt.bDescriptorType)
    {
      case DSC_HID: //HID Descriptor
        sendSerialDebugMessage("SetupPkt.bDescriptorType == DSC_HID");
        if(usb.GetDeviceState() >= CONFIGURED_STATE)
        {
          //18 is a magic number.  It is the offset from start of the configuration descriptor to the start of the HID descriptor.
          usb.EP0SendROMPtr((uint8_t*)&configDescriptor1 + 18,sizeof(USB_HID_DSC)+3,USB_EP0_INCLUDE_ZERO);
        }
        break;
      case DSC_RPT:  //Report Descriptor
        sendSerialDebugMessage("SetupPkt.bDescriptorType == DSC_RPT");
        sendSerialDebugMessage("SetupPkt.wIndex = ",(int) SetupPkt.wIndex);
        if(usb.GetDeviceState() >= CONFIGURED_STATE)
        {
          switch(SetupPkt.wIndex) // figure out which interface the requested report descriptor
          {
            case 0: // interface 0
              usb.EP0SendROMPtr((uint8_t*)ReportDescriptorMouse,sizeof(ReportDescriptorMouse),USB_EP0_INCLUDE_ZERO);
              break;
          }
          //See usbcfg.h
        }
        break;
      case DSC_PHY:  //Physical Descriptor
        sendSerialDebugMessage("SetupPkt.bDescriptorType == DSC_PHY");
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
        sendSerialDebugMessage("SetupPkt.bDescriptorType = ",(int) SetupPkt.bDescriptorType);
        break;
    }//end switch(SetupPkt.bDescriptorType)
  }//end if(SetupPkt.bRequest == GET_DSC)
    
  if(SetupPkt.RequestType != USB_SETUP_TYPE_CLASS_BITFIELD)
  {
    sendSerialDebugMessage("SetupPkt.bRequest == USB_SETUP_TYPE_CLASS_BITFIELD");
    usb.EP0Transmit(USB_EP0_NO_DATA);
    return;
  }

  switch(SetupPkt.bRequest)
  {
    case GET_REPORT:
      sendSerialDebugMessage("SetupPkt.bRequest == GET_REPORT");
      #if defined USER_GET_REPORT_HANDLER
        USER_GET_REPORT_HANDLER();
      #endif
      break;
    case SET_REPORT:
      sendSerialDebugMessage("SetupPkt.bRequest == SET_REPORT");
      #if defined USER_SET_REPORT_HANDLER
        USER_SET_REPORT_HANDLER();
      #endif       
      break;
    case GET_IDLE:
      sendSerialDebugMessage("SetupPkt.bRequest == GET_IDLE");
      usb.EP0SendRAMPtr((uint8_t*)&idle_rate,1,USB_EP0_INCLUDE_ZERO);
      break;
    case SET_IDLE:
      sendSerialDebugMessage("SetupPkt.bRequest == SET_IDLE");
      usb.EP0Transmit(USB_EP0_NO_DATA);
      idle_rate = SetupPkt.W_Value.byte.HB;
      break;
    case GET_PROTOCOL:
      sendSerialDebugMessage("SetupPkt.bRequest == GET_PROTOCOL");
      usb.EP0SendRAMPtr((uint8_t*)&active_protocol,1,USB_EP0_NO_OPTIONS);
      break;
    case SET_PROTOCOL:
      sendSerialDebugMessage("SetupPkt.bRequest == SET_PROTOCOL");
      usb.EP0Transmit(USB_EP0_NO_DATA);
      active_protocol = SetupPkt.W_Value.byte.LB;
      break;
    default:
       sendSerialDebugMessage("SetupPkt.bRequest = ",(int) SetupPkt.bRequest);
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
      sendSerialDebugMessage("EVENT_TRANSFER");
      //Add application specific callback task or callback function here if desired.
      break;
    case EVENT_SOF:
      //Serial1.println("EVENT_SOF"); // This happens alot
      break;
    case EVENT_SUSPEND:
      sendSerialDebugMessage("EVENT_SUSPEND");
      break;
    case EVENT_RESUME:
      sendSerialDebugMessage("EVENT_RESUME");
      break;
    case EVENT_CONFIGURED:
      sendSerialDebugMessage("EVENT_CONFIGURED");
      // Enable Endpoint 1 (HID_EP) for both input and output... 2 endpoints are used for this.
      usb.EnableEndpoint(HID_EP,USB_OUT_ENABLED|USB_IN_ENABLED|USB_HANDSHAKE_ENABLED|USB_DISALLOW_SETUP);

      // set up to wait (arm) for a command to come in on EP 1 (HID_EP) 
      rgHost2Device[0] = 0;
      hHost2Device = usb.GenRead(HID_EP, rgHost2Device, USB_EP_SIZE);
      break;
    case EVENT_SET_DESCRIPTOR:
      sendSerialDebugMessage("EVENT_SET_DESCRIPTOR");
      break;
    case EVENT_EP0_REQUEST:
      sendSerialDebugMessage("EVENT_EP0_REQUEST");
      // this is the handler to deal with EP 0 request
      // this is where our HID device talks to the USB Host controller   
      USBCheckHIDRequest();
      break;
    case EVENT_BUS_ERROR:
      sendSerialDebugMessage("EVENT_BUS_ERROR");
      break;
    case EVENT_TRANSFER_TERMINATED:
      sendSerialDebugMessage("EVENT_TRANSFER_TERMINATED");
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
      sendSerialDebugMessage("event = ",(int) event);
      break;
  }      
}

void sendSerialDebugMessage(String Str)
{
#ifdef SerialDebug
  Serial1.println(str);
#endif
}

void sendSerialDebugMessage(String Str, int val)
{
#ifdef SerialDebug
  Serial1.print(str);
  Serial1.println(val,HEX);
#endif
}

void sendUsbChanges() {
  // make sure the HOST has read everything we have sent it, and we can put new stuff in the buffer
  if(!usb.HandleBusy(hDevice2Host))
  {
    hDevice2Host = usb.GenWrite(HID_EP, rgDevice2Host, 4);	// write out our data
  }
}
#endif
