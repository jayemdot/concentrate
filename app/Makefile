APP_NAME = Concentrate
CONFIG   = release
BIN_DIR  = $(shell swift build -c $(CONFIG) --show-bin-path)
APP_DIR  = build/$(APP_NAME).app
# Apple Development 証明書があればそれで署名(TCC 権限が再ビルドでも保持される)。
# 無ければ ad-hoc にフォールバック。
SIGN_ID  = $(shell security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $$2; exit}')

.PHONY: build app run log clean reset-perm reset-passcode

## Swift パッケージをビルド
build:
	swift build -c $(CONFIG)

## .app バンドルを組み立てて ad-hoc 署名(TCC を安定させるため)
app: build
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources
	cp $(BIN_DIR)/$(APP_NAME) $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(APP_DIR)/Contents/Info.plist
	@if [ -n "$(SIGN_ID)" ]; then \
		echo "▶ 署名: $(SIGN_ID)"; \
		codesign --force --sign "$(SIGN_ID)" $(APP_DIR); \
	else \
		echo "▶ 署名: ad-hoc (Apple Development 証明書なし)"; \
		codesign --force --sign - $(APP_DIR); \
	fi
	@echo "✅ $(APP_DIR) を生成しました"

## TCC(アクセシビリティ)権限をリセットして再許可できるようにする
reset-perm:
	tccutil reset Accessibility com.jayemdot.concentrate
	@echo "✅ アクセシビリティ権限をリセットしました。次回起動時に再許可してください"

## 解除パスコードを削除(次回起動時に再設定を促す)
reset-passcode:
	-security delete-generic-password -s com.jayemdot.concentrate -a unlock-passcode >/dev/null 2>&1
	@echo "✅ パスコードを削除しました。次回起動時に再設定してください"

## ビルドして起動(LaunchServices 経由 = TCC 判定が安定)
run: app
	open $(APP_DIR)

## ログを見る(別ターミナルで)
log:
	log stream --predicate 'subsystem == "com.jayemdot.concentrate"' --level info

clean:
	swift package clean
	rm -rf build
