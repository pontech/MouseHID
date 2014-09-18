// 20140316 //the version of mpide this code was developed and tested in.
#include <chipKITUSBDevice.h>
#include "DetectEdge.h"

// include HID for HID declarations; not part of the standard USB Device library include
#include "chipKITUSBHIDFunction.h"
#include "HIDcode.h"

/************************************************************************/
/*									*/
/*	MouseHID.pde	-- Demonstrates a Standard HID USB Mouse         */
/*		    using the chipKIT Max32 and chipKIT Network Shield,	*/
/*			  Quick240 or other Direct Usb ChipKIT board	*/
/************************************************************************/
/*	Author: 	Jacob Christ, Michael Skoczen 			*/
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

#define LButtonPin C0IO0 //This example was developed on a Quick240
#define MButtonPin C0IO1 //we used its pin names
#define RButtonPin C0IO2
#define WheelUpPin C1IO2
#define WheelDnPin C1IO3
#define XposPin C2IO0
#define XnegPin C2IO1
#define YposPin C2IO2
#define YnegPin C2IO3

DetectEdge LButtonEdge(LButtonPin,true,10);
DetectEdge MButtonEdge(MButtonPin,true,10);
DetectEdge RButtonEdge(RButtonPin,true,10);
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
  
  // wait until we get configured
  // this should already be done becasue we said to wait until configured on InitializeSystem
  while(usb.GetDeviceState() < CONFIGURED_STATE);
	
  // set the Buttons as an inputs
  pinMode(LButtonPin,INPUT);
  pinMode(MButtonPin,INPUT);
  pinMode(RButtonPin,INPUT);
  pinMode(WheelUpPin,INPUT);
  pinMode(WheelDnPin,INPUT);
  pinMode(XposPin,INPUT);
  pinMode(XnegPin,INPUT);
  pinMode(YposPin,INPUT);
  pinMode(YnegPin,INPUT);
}

void loop() {
  LButtonEdge.scan();
  MButtonEdge.scan();
  RButtonEdge.scan();
  
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
    rgDevice2Host[1] = 4; // x
    ButtonsDownUpdated = true;
  }
  if(digitalRead(XnegPin)==LOW)
  {
    rgDevice2Host[1] = -4; // x
    ButtonsDownUpdated = true;
  }
  if(digitalRead(YposPin)==LOW)
  {
    rgDevice2Host[2] = 4; // y
    ButtonsDownUpdated = true;
  }
  if(digitalRead(YnegPin)==LOW)
  {
    rgDevice2Host[2] = -4; // y
    ButtonsDownUpdated = true;
  }
  if(ButtonsDownUpdated)
  {
    rgDevice2Host[0] = ButtonsDown; // Mouse buttons
    sendUsbChanges();
    //zero the controls that use relative position
    rgDevice2Host[1] = 0; // x
    rgDevice2Host[2] = 0; // y
    rgDevice2Host[3] = 0; // wheel
    ButtonsDownUpdated = false;
  }
 
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
      rgDevice2Host[1] = 10; // x
      sendUsbChanges();
    }
    else if (strcmp(serial_command, "movey") == 0)
    {
      rgDevice2Host[2] = 10; // y
      sendUsbChanges();
    }
    else if (strcmp(serial_command, "buttondn") == 0)
    {
      rgDevice2Host[0] = 0x01; // Mouse buttons
      sendUsbChanges();
    }
    else if (strcmp(serial_command, "buttonup") == 0)
    {
      rgDevice2Host[0] = 0x00; // Mouse buttons
      sendUsbChanges();
    }
    else //none of the ifs above were true
    {
      Serial1.println("Command not recognized");
    }
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


