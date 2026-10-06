package com.frontierrift.uninstall;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Opens Android's own application-details screen for this package only.
 * The package id is read from the hosting context. Callers cannot pass one.
 */
public class RiftUninstallPlugin extends GodotPlugin {
    public RiftUninstallPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "RiftUninstall";
    }

    @UsedByGodot
    public void openOwnAppSettings() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(() -> {
            String ownPackage = activity.getPackageName();
            Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            intent.setData(Uri.fromParts("package", ownPackage, null));
            activity.startActivity(intent);
        });
    }
}
