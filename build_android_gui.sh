# ===============================
# Termux Android GUI 构建器 (完整版)
# 作者：ChatGPT (GPT-5)
# ===============================

echo "🔄 更新系统..."
pkg update -y && pkg upgrade -y

echo "📦 安装依赖..."
pkg install -y openjdk-17 aapt apksigner dx ecj zipalign wget unzip git

export JAVA_HOME=$PREFIX/lib/jvm/openjdk-17
export PATH=$PATH:$JAVA_HOME/bin:$PREFIX/bin

# ===============================
# 自定义信息
# ===============================
read -p "请输入 App 名称 (默认 HelloUI)： " APP_NAME
APP_NAME=${APP_NAME:-HelloUI}

read -p "请输入 包名 (默认 com.termux.helloui)： " PKG_NAME
PKG_NAME=${PKG_NAME:-com.termux.helloui}

read -p "请输入版本号 (默认 1.0)： " APP_VER
APP_VER=${APP_VER:-1.0}

APP_DIR="$HOME/${APP_NAME}App"
MAIN_CLASS="MainActivity"

echo "📁 创建项目目录：$APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"/{src,build,res/layout,res/values,res/mipmap-anydpi-v26,temp}

cd "$APP_DIR"

# ===============================
# Java 代码生成
# ===============================
cat > src/$MAIN_CLASS.java <<EOF
package $PKG_NAME;

import android.app.Activity;
import android.os.Bundle;
import android.widget.*;
import android.view.*;

public class $MAIN_CLASS extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        Button btn = findViewById(R.id.btnClick);
        TextView tv = findViewById(R.id.textMsg);
        btn.setOnClickListener(v -> tv.setText("按钮已点击 🎉"));
    }
}
EOF

# ===============================
# AndroidManifest.xml
# ===============================
cat > AndroidManifest.xml <<EOF
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PKG_NAME"
    android:versionName="$APP_VER">
    <application android:label="$APP_NAME" android:icon="@mipmap/ic_launcher">
        <activity android:name=".$MAIN_CLASS" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# ===============================
# 布局文件 (main.xml)
# ===============================
cat > res/layout/main.xml <<'EOF'
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:orientation="vertical"
    android:padding="30dp"
    android:gravity="center"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:id="@+id/textMsg"
        android:text="Hello Termux GUI!"
        android:textSize="24sp"
        android:layout_marginBottom="20dp"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />

    <Button
        android:id="@+id/btnClick"
        android:text="点击我"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content" />
</LinearLayout>
EOF

# ===============================
# 字符串资源
# ===============================
cat > res/values/strings.xml <<EOF
<resources>
    <string name="app_name">$APP_NAME</string>
</resources>
EOF

# ===============================
# 编译
# ===============================
echo "🧩 编译 Java..."
javac -d build -classpath /system/framework/android.jar src/$MAIN_CLASS.java

echo "🌀 生成 DEX..."
dx --dex --output=classes.dex build/

echo "📦 打包 APK..."
aapt package -f -m -F app.apk -M AndroidManifest.xml -S res -I /system/framework/framework-res.apk

cd temp
unzip ../app.apk -d .
cp ../classes.dex .
zip -r ../unsigned.apk .
cd ..

# ===============================
# 签名
# ===============================
if [ ! -f key.jks ]; then
    echo "🔏 生成签名密钥..."
    keytool -genkey -v -keystore key.jks -storepass 123456 -keypass 123456 \
        -alias key -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Termux,O=Android,C=US"
fi

echo "✍️ 签名 APK..."
apksigner sign --ks key.jks --ks-pass pass:123456 --out ${APP_NAME}.apk temp/unsigned.apk

# ===============================
# 完成提示
# ===============================
echo ""
echo "✅ 编译完成！"
echo "📦 APK 位置：$APP_DIR/${APP_NAME}.apk"
echo ""
echo "👉 安装命令："
echo "termux-open $APP_DIR/${APP_NAME}.apk"
echo ""
echo "🎉 启动后界面："
echo "一个按钮 + 文本视图，点击按钮会显示『按钮已点击 🎉』"