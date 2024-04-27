/*
    Copyright 2016-2023 melonDS team

    This file is part of melonDS.

    melonDS is free software: you can redistribute it and/or modify it under
    the terms of the GNU General Public License as published by the Free
    Software Foundation, either version 3 of the License, or (at your option)
    any later version.

    melonDS is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with melonDS. If not, see http://www.gnu.org/licenses/.
*/

#ifndef DSI_H
#define DSI_H

#include "NDS.h"
#include "DSi_NDMA.h"
#include "DSi_SD.h"
#include "DSi_DSP.h"
#include "DSi_AES.h"
#include "DSi_Camera.h"
#include "DSi_NAND.h"

namespace melonDS
{
class DSi_I2CHost;
class DSi_CamModule;
class DSi_AES;
class DSi_DSP;
class DSiArgs;

namespace DSi_NAND
{
    class NANDImage;
}

class DSi final : public NDS
{
protected:
    void DoSavestateExtra(Savestate* file) override;
public:
    u16 SCFG_BIOS;
    u16 SCFG_Clock9;
    u32 SCFG_EXT[2];

    std::array<u8, DSiBIOSSize> ARM9iBIOS;
    std::array<u8, DSiBIOSSize> ARM7iBIOS;
    DSi_SDHost SDMMC;
    DSi_SDHost SDIO;

    const u32 NWRAMSize = 0x40000;

    u8* NWRAM_A;
    u8* NWRAM_B;
    u8* NWRAM_C;

    u8* NWRAMMap_A[2][4];
    u8* NWRAMMap_B[3][8];
    u8* NWRAMMap_C[3][8];

    u32 NWRAMStart[2][3];
    u32 NWRAMEnd[2][3];
    u32 NWRAMMask[2][3];

    DSi_I2CHost I2C;
    DSi_CamModule CamModule;
    DSi_AES AES;
    DSi_DSP DSP;

    void Reset() override;
    void Stop(Platform::StopReason reason) override;

    bool DoSavestate(Savestate* file);

    void SetCartInserted(bool inserted);

    void SetupDirectBoot() override;
    void SoftReset();

    bool LoadNAND();

    void RunNDMAs(u32 cpu);
    void StallNDMAs();
    bool NDMAsInMode(u32 cpu, u32 mode) const;
    bool NDMAsRunning(u32 cpu) const;
    void CheckNDMAs(u32 cpu, u32 mode);
    void StopNDMAs(u32 cpu, u32 mode);

    void MapNWRAM_A(u32 num, u8 val);
    void MapNWRAM_B(u32 num, u8 val);
    void MapNWRAM_C(u32 num, u8 val);
    void MapNWRAMRange(u32 cpu, u32 num, u32 val);

    u8 ARM9Read8(u32 addr) override;
    u16 ARM9Read16(u32 addr) override;
    u32 ARM9Read32(u32 addr) override;
    void ARM9Write8(u32 addr, u8 val) override;
    void ARM9Write16(u32 addr, u16 val) override;
    void ARM9Write32(u32 addr, u32 val) override;

    bool ARM9GetMemRegion(u32 addr, bool write, MemRegion* region) override;

    u8 ARM7Read8(u32 addr) override;
    u16 ARM7Read16(u32 addr) override;
    u32 ARM7Read32(u32 addr) override;
    void ARM7Write8(u32 addr, u8 val) override;
    void ARM7Write16(u32 addr, u16 val) override;
    void ARM7Write32(u32 addr, u32 val) override;

    bool ARM7GetMemRegion(u32 addr, bool write, MemRegion* region) override;

    u8 ARM9IORead8(u32 addr) override;
    u16 ARM9IORead16(u32 addr) override;
    u32 ARM9IORead32(u32 addr) override;
    void ARM9IOWrite8(u32 addr, u8 val) override;
    void ARM9IOWrite16(u32 addr, u16 val) override;
    void ARM9IOWrite32(u32 addr, u32 val) override;

    u8 ARM7IORead8(u32 addr) override;
    u16 ARM7IORead16(u32 addr) override;
    u32 ARM7IORead32(u32 addr) override;
    void ARM7IOWrite8(u32 addr, u8 val) override;
    void ARM7IOWrite16(u32 addr, u16 val) override;
    void ARM7IOWrite32(u32 addr, u32 val) override;

public:
    DSi(DSiArgs&& args) noexcept;
    ~DSi() noexcept override;
    DSi(const DSi&) = delete;
    DSi& operator=(const DSi&) = delete;
    DSi(DSi&&) = delete;
    DSi& operator=(DSi&&) = delete;
    void SetNDSCart(std::unique_ptr<NDSCart::CartCommon>&& cart) override;
    std::unique_ptr<NDSCart::CartCommon> EjectCart() override;
    bool NeedsDirectBoot() const override
    {
        // for now, DSi mode requires original BIOS/NAND
        return false;
    }

    [[nodiscard]] const DSi_NAND::NANDImage& GetNAND() const noexcept { return *SDMMC.GetNAND(); }
    [[nodiscard]] DSi_NAND::NANDImage& GetNAND() noexcept { return *SDMMC.GetNAND(); }
    void SetNAND(DSi_NAND::NANDImage&& nand) noexcept { SDMMC.SetNAND(std::move(nand)); }
    u64 GetConsoleID() const noexcept { return SDMMC.GetNAND()->GetConsoleID(); }

    [[nodiscard]] const FATStorage* GetSDCard() const noexcept { return SDMMC.GetSDCard(); }
    void SetSDCard(FATStorage&& sdcard) noexcept { SDMMC.SetSDCard(std::move(sdcard)); }
    void SetSDCard(std::optional<FATStorage>&& sdcard) noexcept { SDMMC.SetSDCard(std::move(sdcard)); }

    void CamInputFrame(int cam, const u32* data, int width, int height, bool rgb) override;
    bool DMAsInMode(u32 cpu, u32 mode) const override;
    bool DMAsRunning(u32 cpu) const override;
    void StopDMAs(u32 cpu, u32 mode) override;
    void CheckDMAs(u32 cpu, u32 mode) override;
    u16 SCFG_Clock7;
    u32 SCFG_MC;
    u16 SCFG_RST;
    u32 MBK[2][9];
    u32 NDMACnt[2];
    std::array<DSi_NDMA, 8> NDMAs;
    // FIXME: these currently have no effect (and aren't stored in a savestate)
    //        ... not that they matter all that much
    u8 GPIO_Data;
    u8 GPIO_Dir;
    u8 GPIO_IEdgeSel;
    u8 GPIO_IE;
    u8 GPIO_WiFi;

    bool GetFullBIOSBoot() const noexcept { return FullBIOSBoot; }
    void SetFullBIOSBoot(bool full) noexcept { FullBIOSBoot = full; }
private:
    bool FullBIOSBoot;
    void Set_SCFG_Clock9(u16 val);
    void Set_SCFG_MC(u32 val);
    void DecryptModcryptArea(u32 offset, u32 size, const u8* iv);
    void ApplyNewRAMSize(u32 size);
};

}
#endif // DSI_H
