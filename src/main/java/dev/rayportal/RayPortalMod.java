package dev.rayportal;

import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;

@Mod(value = RayPortalMod.MOD_ID, dist = Dist.CLIENT)
public final class RayPortalMod {
    public static final String MOD_ID = "rayportal";

    public RayPortalMod(IEventBus modEventBus, ModContainer modContainer) {
        // Feature registration will be added after the baseline architecture is agreed.
    }
}
