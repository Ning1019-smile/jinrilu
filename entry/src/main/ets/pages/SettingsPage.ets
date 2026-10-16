import { promptAction } from '@kit.ArkUI';
import { Db } from '../common/Db';
import { Backup } from '../common/Backup';
import { PrivacyDialog } from '../common/PrivacyDialog';
import { Theme, PHRASE_SEP } from '../common/Style';

// 字号档位：0标准 1大 2特大
const SCALE_MAP: Array<number> = [1.0, 1.15, 1.3];

@Component
export struct SettingsPage {
  @StorageProp('fontScale') fsNum: number = 1;
  @State fontChoice: number = 0;
  @State phrases: Array<string> = [];
  @State newPhrase: string = '';
  @State backupOn: boolean = false;
  private privacyCtrl: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog({
      agreeText: '我知道了',
      disagreeText: '',
      onAgree: () => {}
    }),
    autoCancel: true,
    customStyle: true
  });

  aboutToAppear(): void {
    this.fontChoice = AppStorage.get<number>('fontChoice') ?? 0;
    this.phrases = (AppStorage.get<string>('quickPhrases') ?? '').split(PHRASE_SEP)
      .filter((s: string) => s.length > 0);
    this.backupOn = AppStorage.get<boolean>('backupReminder') ?? true;
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  async chooseFont(n: number): Promise<void> {
    this.fontChoice = n;
    AppStorage.setOrCreate('fontChoice', n);
    AppStorage.setOrCreate('fontScale', SCALE_MAP[n]);
    await Db.setSetting('fontChoice', n.toString());
    promptAction.showToast({ message: n === 0 ? '标准字号' : (n === 1 ? '已调大字号' : '已调为特大字号') });
  }

  async savePhrases(): Promise<void> {
    const joined: string = this.phrases.join(PHRASE_SEP);
    AppStorage.setOrCreate('quickPhrases', joined);
    await Db.setSetting('quickPhrases', joined);
  }

  async addPhrase(): Promise<void> {
    const p: string = this.newPhrase.trim();
    if (p.length === 0) {
      return;
    }
    if (p.indexOf(PHRASE_SEP) >= 0) {
      promptAction.showToast({ message: '常用语不能包含 | 符号' });
      return;
    }
    if (this.phrases.indexOf(p) >= 0) {
      promptAction.showToast({ message: '这条常用语已经有了' });
      return;
    }
    this.phrases.push(p);
    this.newPhrase = '';
    await this.savePhrases();
  }

  async removePhrase(idx: number): Promise<void> {
    this.phrases.splice(idx, 1);
    await this.savePhrases();
  }

  async toggleBackup(on: boolean): Promise<void> {
    this.backupOn = on;
    await Db.setSetting('backupReminder', on ? '1' : '0');
  }

  bumpData(): void {
    const v = AppStorage.get<number>('dataVersion') ?? 0;
    AppStorage.setOrCreate('dataVersion', v + 1);
  }

  async exportData(): Promise<void> {
    try {
      const n = await Backup.exportAll();
      if (n !== null) {
        promptAction.showToast({ message: '已导出 ' + n.toString() + ' 条记录' });
      }
    } catch (err) {
      promptAction.showToast({ message: '导出失败，请重试' });
    }
  }

  async importData(): Promise<void> {
    try {
      const res = await Backup.importMerge();
      if (res !== null) {
        this.bumpData();
        promptAction.showToast({ message: '导入完成：新增 ' + res.added.toString() + ' 条，重复跳过 ' + res.skipped.toString() + ' 条' });
      }
    } catch (err) {
      promptAction.showToast({ message: '导入失败，请选择正确的备份文件' });
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('设置')
          .fontSize(this.fz(22))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .width('92%')
          .margin({ top: 12, bottom: 10 })

        // 字号
        Column() {
          Text('字号')
            .fontSize(this.fz(16))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
            .margin({ bottom: 10 })
          Row() {
            Text('标准')
              .fontSize(this.fz(15))
              .fontColor(this.fontChoice === 0 ? Theme.brandText : Theme.text)
              .backgroundColor(this.fontChoice === 0 ? Theme.brandSoft : Theme.bg)
              .borderRadius(10)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .margin({ right: 8 })
              .onClick(() => this.chooseFont(0))
            Text('大')
              .fontSize(this.fz(17))
              .fontColor(this.fontChoice === 1 ? Theme.brandText : Theme.text)
              .backgroundColor(this.fontChoice === 1 ? Theme.brandSoft : Theme.bg)
              .borderRadius(10)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .margin({ right: 8 })
              .onClick(() => this.chooseFont(1))
            Text('特大')
              .fontSize(this.fz(19))
              .fontColor(this.fontChoice === 2 ? Theme.brandText : Theme.text)
              .backgroundColor(this.fontChoice === 2 ? Theme.brandSoft : Theme.bg)
              .borderRadius(10)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .onClick(() => this.chooseFont(2))
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ bottom: 12 })

        // 常用语
        Column() {
          Text('常用语')
            .fontSize(this.fz(16))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
            .margin({ bottom: 4 })
          Text('记事件时点一下就能填入，不用打字')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
            .width('100%')
            .margin({ bottom: 10 })

          if (this.phrases.length === 0) {
            Text('还没有常用语')
              .fontSize(this.fz(14))
              .fontColor(Theme.textMut)
              .width('100%')
              .margin({ bottom: 8 })
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.phrases, (p: string, idx: number) => {
                Row() {
                  Text(p)
                    .fontSize(this.fz(14))
                    .fontColor(Theme.brandText)
                  Text(' ×')
                    .fontSize(this.fz(14))
                    .fontColor(Theme.textMut)
                    .margin({ left: 4 })
                }
                .backgroundColor(Theme.brandSoft)
                .borderRadius(15)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => this.removePhrase(idx))
              }, (p: string) => p)
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          Row() {
            TextInput({ text: this.newPhrase, placeholder: '添加常用语，如：散步' })
              .fontSize(this.fz(15))
              .placeholderFont({ size: this.fz(14) })
              .placeholderColor(Theme.textMut)
              .height(42)
              .layoutWeight(1)
              .backgroundColor(Theme.bg)
              .borderRadius(10)
              .enterKeyType(EnterKeyType.Done)
              .onChange((v: string) => {
                this.newPhrase = v;
              })
              .onSubmit(() => this.addPhrase())
            Button('添加')
              .fontSize(this.fz(14))
              .height(42)
              .fontColor($r('app.color.on_brand'))
              .backgroundColor(Theme.brand)
              .borderRadius(10)
              .margin({ left: 8 })
              .onClick(() => this.addPhrase())
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ bottom: 12 })

        // 备份提醒
        Column() {
          Row() {
            Column() {
              Text('备份提醒')
                .fontSize(this.fz(16))
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text)
              Text('每月提醒一次，导出备份文件，防止换机丢数据')
                .fontSize(this.fz(13))
                .fontColor(Theme.textMut)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.backupOn })
              .selectedColor(Theme.brand)
              .onChange((on: boolean) => this.toggleBackup(on))
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ bottom: 12 })

        // 备份与恢复
        Column() {
          Text('备份与恢复')
            .fontSize(this.fz(16))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
          Text('导出备份文件保存好；换手机时在新手机上导入即可恢复')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
            .width('100%')
            .margin({ top: 4, bottom: 10 })
          Row() {
            Button('导出备份')
              .fontSize(this.fz(15))
              .height(44)
              .fontColor($r('app.color.on_brand'))
              .backgroundColor(Theme.brand)
              .borderRadius(10)
              .layoutWeight(1)
              .onClick(() => this.exportData())
            Button('导入备份')
              .fontSize(this.fz(15))
              .height(44)
              .fontColor($r('app.color.on_brand'))
              .backgroundColor(Theme.brand)
              .borderRadius(10)
              .layoutWeight(1)
              .margin({ left: 10 })
              .onClick(() => this.importData())
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ bottom: 12 })
        // 隐私政策
        Column() {
          Row() {
            Column() {
              Text('隐私政策')
                .fontSize(this.fz(16))
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.text)
              Text('全文内置在本应用中，无需联网即可查看')
                .fontSize(this.fz(13))
                .fontColor(Theme.textMut)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('查看 >')
              .fontSize(this.fz(14))
              .fontColor(Theme.brandText)
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ bottom: 12 })
        .onClick(() => this.privacyCtrl.open())
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
