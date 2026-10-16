import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { Theme } from './Style';

// 隐私政策弹窗：全文内置在 rawfile/privacy.txt，离线可读，不依赖网络
// disagreeText 为空串时不显示"不同意"按钮（设置页查看场景）
@CustomDialog
export struct PrivacyDialog {
  controller?: CustomDialogController;
  onAgree: () => void = () => {};
  @StorageProp('fontScale') fsNum: number = 1;
  agreeText: string = '同意并继续';
  disagreeText: string = '不同意';
  @State content: string = '加载中…';

  aboutToAppear(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const bytes = ctx.resourceManager.getRawFileContentSync('privacy.txt');
      this.content = util.TextDecoder.create('utf-8').decodeToString(bytes);
    } catch (err) {
      this.content = '隐私政策加载失败。';
    }
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  build() {
    Column() {
      Text('用户协议与隐私政策')
        .fontSize(this.fz(19))
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.text)
        .margin({ top: 20, bottom: 4 })
      Text('请仔细阅读以下内容，了解您的数据如何被对待')
        .fontSize(this.fz(13))
        .fontColor(Theme.textMut)
        .margin({ bottom: 12 })

      Scroll() {
        Text(this.content)
          .fontSize(this.fz(14))
          .fontColor(Theme.text)
          .lineHeight(this.fz(23))
          .width('100%')
      }
      .constraintSize({ maxHeight: 430 })
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
      .width('100%')
      .backgroundColor(Theme.bg)
      .borderRadius(10)
      .padding(12)

      Row() {
        if (this.disagreeText.length > 0) {
          Button(this.disagreeText)
            .fontSize(this.fz(15))
            .height(44)
            .fontColor(Theme.textMut)
            .backgroundColor(Theme.bg)
            .borderRadius(10)
            .layoutWeight(1)
            .onClick(() => {
              this.controller?.close();
              (getContext(this) as common.UIAbilityContext).terminateSelf();
            })
        }
        Button(this.agreeText)
          .fontSize(this.fz(15))
          .height(44)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor(Theme.brand)
          .borderRadius(10)
          .layoutWeight(1)
          .margin({ left: this.disagreeText.length > 0 ? 10 : 0 })
          .onClick(() => {
            this.onAgree();
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 14, bottom: 18 })
    }
    .width('92%')
    .backgroundColor(Theme.card)
    .borderRadius(16)
    .padding({ left: 16, right: 16 })
  }
}
