package io.flutter.examples.hello_world;

import android.os.Bundle;
import io.flutter.app.FlutterActivity;
import io.flutter.plugins.PluginRegistry;

public class MainActivity extends FlutterActivity {
    PluginRegistry pluginRegistry;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        pluginRegistry = new PluginRegistry();
        pluginRegistry.registerAll(this);
    }
}
