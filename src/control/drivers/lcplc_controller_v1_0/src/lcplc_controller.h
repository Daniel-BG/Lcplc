/*
 * lcplc_ctrl.h
 *
 *  Created on: 10 abr. 2019
 *      Author: Daniel
 */

#ifndef SRC_LCPLC_CTRL_H_
#define SRC_LCPLC_CTRL_H_

#include "xil_types.h"
#include "xil_io.h"

#define XPAR_XLCPLC_USE_DCR_BRIDGE 0

#define LCPLC_REG_CTRLRG_OFFSET 0		//control register
#define LCPLC_REG_STADDR_OFFSET 4		//addr start of raw data

#define LCPLC_REG_BYTENO_OFFSET 12		//total bytes to be read (BYTES, not samples)
#define LCPLC_REG_SMPLNO_OFFSET 16		//number of samples in image (x-dim)
#define LCPLC_REG_LINENO_OFFSET 20		//number of lines in image   (y-dim)
#define LCPLC_REG_BANDNO_OFFSET 24		//number of bands in image	 (z-dim)
#define LCPLC_REG_TGADDR_OFFSET 28   	//addr start of output data
#define LCPLC_REG_BCKSMP_OFFSET 32 		//number of samples in block
#define LCPLC_REG_BCKLIN_OFFSET 36		//number of lines in block
#define LCPLC_REG_THRESL_OFFSET 40		//threshold lower part
#define LCPLC_REG_THRESU_OFFSET 44   	//threshold upper part
#define LCPLC_REG_QSHIFT_OFFSET 48   	//shift value for quantizer
#define LCPLC_REG_STATUS_OFFSET 128  	//status of lcplc
#define LCPLC_REG_INBYTE_OFFSET 132		//number of bytes read from mem so far
#define LCPLC_REG_OUTBYT_OFFSET 136  	//number of bytes output so far
#define LCPLC_REG_DDRWST_OFFSET 140  	//ddr write status register
#define LCPLC_REG_DDRRST_OFFSET 144  	//ddr read status register
#define LCPLC_REG_CNCLKL_OFFSET 148  	//lower part of clock count for control bus
#define LCPLC_REG_CNCLKU_OFFSET 152  	//upper part of clock count for control bus
#define LCPLC_REG_MMCLKL_OFFSET 156  	//lower part of clock count for memory bus
#define LCPLC_REG_MMCLKU_OFFSET 160  	//upper part of clock count for memory bus
#define LCPLC_REG_LCCLKL_OFFSET 164  	//lower part of clock count for lcplc core
#define LCPLC_REG_LCCLKU_OFFSET 168  	//upper part of clock count for lcplc core
#define LCPLC_REG_GENSIZ_OFFSET 192  	//lcplc input and output axis sizes
#define LCPLC_REG_GENMAX_OFFSET 196  	//max size allowed for block and image
#define LCPLC_REG_GENOTH_OFFSET 200 	//others
#define LCPLC_REG_GENBUS_OFFSET 204 	//info about control and data buses
#define LCPLC_REG_DBGREG_OFFSET 252		//some debug info

#define LCPLC_CONTROL_CODE_NULL 	0
#define LCPLC_CONTROL_CODE_RESET 	127
#define LCPLC_CONTROL_CODE_START_0 	62
#define LCPLC_CONTROL_CODE_START_1 	63

#define LCPLC_STATUS_IDLE			0x1
#define LCPLC_STATUS_RESET			0x10
#define LCPLC_STATUS_WAIT_START_1 	0x100
#define LCPLC_STATUS_START 			0x1000
#define LCPLC_STATUS_ABRUPT_END		0x10000
#define LCPLC_STATUS_END 			0x100000

#define LCPLC_INPUT_BYTE_WIDTH 2

/*
 * Define the appropriate I/O access method to memory mapped I/O or DCR.
 */


#define XLCPLC_In32(A)		(*(volatile u32 *) (A))
#define XLCPLC_Out32(A, B)	((*(volatile u32 *) (A)) = (B))


/****************************************************************************/
/**
*
* Write a value to a LCPLC register. A 32 bit write is performed.
*
* @param	BaseAddress is the base address of the LCPLC device.
* @param	RegOffset is the register offset from the base to write to.
* @param	Data is the data written to the register.
*
* @return	None.
*
* @note		C-style signature:
*		void XLCPLC_WriteReg(u32 BaseAddress, u32 RegOffset,
*					u32 Data)
*
****************************************************************************/
#define XLCPLC_WriteReg(BaseAddress, RegOffset, Data) \
	XLCPLC_Out32((BaseAddress) + (RegOffset), (u32)(Data))

/****************************************************************************/
/**
*
* Read a value from a LCPLC register. A 32 bit read is performed.
*
* @param	BaseAddress is the base address of the LCPLC device.
* @param	RegOffset is the register offset from the base to read from.
*
* @return	Data read from the register.
*
* @note		C-style signature:
*		u32 XLCPLC_ReadReg(u32 BaseAddress, u32 RegOffset)
*
****************************************************************************/
#define XLCPLC_ReadReg(BaseAddress, RegOffset) \
	XLCPLC_In32((BaseAddress) + (RegOffset))


/************************** Function Prototypes *****************************/

/****************************************************************************/
/**
*
* Set the size registers to the given values
*
* @param	BaseAddress is the base address of the LCPLC device.
* @param	BlockLines number of lines in each block
* @param	BlockSamples number of samples in each block
* @param	ImageBands number of bands in the image
* @param	ImageLines number of lines in the image
* @param	ImageSamples number of samples in the image
*
****************************************************************************/
void XLCPLC_SetSize(UINTPTR BaseAddress, u32 BlockLines, u32 BlockSamples, u32 ImageBands, u32 ImageLines, u32 ImageSamples);

/****************************************************************************/
/**
*
* Resets the LCPLC core that this controller is driving
*
* @param	BaseAddress is the base address of the LCPLC device.
* @param	cycles number of cycles to hold reset state for
*
****************************************************************************/
void XLCPLC_Reset(UINTPTR BaseAddress, u32 cycles);

/****************************************************************************/
/**
*
* Get the current number of cycles elapsed in the memory bus clock
*
* @param	BaseAddress is the base address of the LCPLC device.
*
****************************************************************************/
long long XLCPLC_GetMemTime(UINTPTR BaseAddress);

/****************************************************************************/
/**
*
* Get the current number of cycles elapsed in the control bus clock
*
* @param	BaseAddress is the base address of the LCPLC device.
*
****************************************************************************/
long long XLCPLC_GetCtrlTime(UINTPTR BaseAddress);

/****************************************************************************/
/**
*
* Get the current number of cycles elapsed in the lcplc core clock
*
* @param	BaseAddress is the base address of the LCPLC device.
*
****************************************************************************/
long long XLCPLC_GetLcplcTime(UINTPTR BaseAddress);

/****************************************************************************/
/**
*
* Perform the startup sequence in the LCPLC core. It will be activated 
*	within this routine
*
* @param	BaseAddress is the base address of the LCPLC device.
*
****************************************************************************/
void XLCPLC_Start(UINTPTR BaseAddress);

/****************************************************************************/
/**
*
* Set the addresses from where to read the raw data, and where to leave the
*	compresse result
*
* @param	BaseAddress is the base address of the LCPLC device.
* @param	SourceAddress is the address where the raw input data starts at
* @param	TargetAddress is the address where the processed data will be output
*
****************************************************************************/
void XLCPLC_SetAddresses(UINTPTR BaseAddress, u32 SourceAddress, u32 TargetAddress);

/****************************************************************************/
/**
*
* Check if the LCPLC core is idle
*
* @param	BaseAddress is the base address of the LCPLC device.
*
* @return 	1 if the device is idle, 0 otherwise
*
****************************************************************************/
int XLCPLC_IsIdle(UINTPTR BaseAddress);

/****************************************************************************/
/**
*
* Get the current status of the LCPLC core
*
* @param	BaseAddress is the base address of the LCPLC device.
*
* @return 	the current status of the core
*
* @note 	see constants starting with LCPLC_STATUS_ for a list of statuses
*
****************************************************************************/
int XLCPLC_GetStatus(UINTPTR BaseAddress);


#endif /* SRC_LCPLC_CTRL_H_ */
