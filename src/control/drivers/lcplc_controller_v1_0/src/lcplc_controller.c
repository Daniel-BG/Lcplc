/*
 * lcplc_ctrl.c
 *
 *  Created on: 10 abr. 2019
 *      Author: Daniel
 */


#include "lcplc_controller.h"


void inline XLCPLC_SetSize(UINTPTR BaseAddress, u32 BlockLines, u32 BlockSamples, u32 ImageBands, u32 ImageLines, u32 ImageSamples) {
	XLCPLC_Out32(BaseAddress + LCPLC_REG_BCKLIN_OFFSET, BlockLines-1);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_BCKSMP_OFFSET, BlockSamples-1);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_BANDNO_OFFSET, ImageBands-1);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_LINENO_OFFSET, ImageLines-1);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_SMPLNO_OFFSET, ImageSamples-1);

	XLCPLC_Out32(BaseAddress + LCPLC_REG_BYTENO_OFFSET, ImageBands*ImageLines*ImageSamples*LCPLC_INPUT_BYTE_WIDTH);
}

inline void XLCPLC_Reset(UINTPTR BaseAddress, u32 cycles) {
	XLCPLC_Out32(BaseAddress + LCPLC_REG_CTRLRG_OFFSET, LCPLC_CONTROL_CODE_RESET);
	//wait a few cycles
	for(int i = 0; i < cycles; i++);
	//end wait
	XLCPLC_Out32(BaseAddress + LCPLC_REG_CTRLRG_OFFSET, LCPLC_CONTROL_CODE_NULL);
}

inline long long XLCPLC_GetMemTime(UINTPTR BaseAddress) {
	unsigned int mtime_low, mtime_high;
	mtime_low	= XLCPLC_In32(BaseAddress + LCPLC_REG_MMCLKL_OFFSET);
	mtime_high	= XLCPLC_In32(BaseAddress + LCPLC_REG_MMCLKU_OFFSET);
	return ((long long) mtime_high) << 32 | ((long long) mtime_low);
}

inline void XLCPLC_Start(UINTPTR BaseAddress) {
	XLCPLC_Out32(BaseAddress + LCPLC_REG_CTRLRG_OFFSET, LCPLC_CONTROL_CODE_START_0);
	while (XLCPLC_GetStatus(BaseAddress) != LCPLC_STATUS_WAIT_START_1);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_CTRLRG_OFFSET, LCPLC_CONTROL_CODE_START_1);
}

inline void XLCPLC_SetAddresses(UINTPTR BaseAddress, u32 SourceAddress, u32 TargetAddress) {
	XLCPLC_Out32(BaseAddress + LCPLC_REG_STADDR_OFFSET, SourceAddress);
	XLCPLC_Out32(BaseAddress + LCPLC_REG_TGADDR_OFFSET, TargetAddress);
}

inline int XLCPLC_IsIdle(UINTPTR BaseAddress) {
	return XLCPLC_GetStatus(BaseAddress) == LCPLC_STATUS_IDLE;
}

inline int XLCPLC_GetStatus(UINTPTR BaseAddress) {
	return XLCPLC_In32(BaseAddress + LCPLC_REG_STATUS_OFFSET);
}
