import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Db } from '../common/Db';
import { DEFAULT_PHRASES } from '../common/Style';

const DOMAIN = 0x0000;
const BG_LIGHT = '#F2F3F5';
const BG_DARK = '#121417';

export default class EntryAbility extends UIAbility {
  private mainStage: window.WindowStage | null = null;
  private isDark: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 全局默认值
    AppStorage.setOrCreate('fontScale', 1.0);
    AppStorage.setOrCreate('fontChoice', 0);
    AppStorage.setOrCreate('quickPhrases', DEFAULT_PHRASES);
    AppStorage.setOrCreate('backupReminder', true);
    AppStorage.setOrCreate('dataVersion', 0);

    // 初始化本地数据库并加载用户设置
    Db.init(this.context).then(async () => {
      const fc: string = await Db.getSetting('fontChoice', '0');
      const fcNum: number = Number(fc);
      AppStorage.setOrCreate('fontChoice', fcNum);
      AppStorage.setOrCreate('fontScale', fcNum === 1 ? 1.15 : (fcNum === 2 ? 1.3 : 1.0));
      const qp: string = await Db.getSetting('quickPhrases', DEFAULT_PHRASES);
      AppStorage.setOrCreate('quickPhrases', qp);
      const br: string = await Db.getSetting('backupReminder', '1');
      AppStorage.setOrCreate('backupReminder', br === '1');
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.mainStage = windowStage;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.refreshWindowStyle();
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  // 窗口底色与状态栏文字颜色跟随深浅色，消除页面上下黑边
  private refreshWindowStyle(): void {
    if (this.mainStage === null) {
      return;
    }
    try {
      const cfg = this.context.config;
      this.isDark = cfg !== undefined && cfg !== null
        && cfg.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      const win = this.mainStage.getMainWindowSync();
      // 全屏布局：页面自身背景铺满整屏（含状态栏/导航条区域），从根上消除黑边
      win.setWindowLayoutFullScreen(true);
      win.setWindowBackgroundColor(this.isDark ? BG_DARK : BG_LIGHT);
      win.setWindowSystemBarProperties({
        // 系统栏底色全透明：让页面自己的背景透出来，避免反色/黑边
        statusBarColor: '#00000000',
        statusBarContentColor: this.isDark ? '#E6E8EB' : '#1F2329',
        navigationBarColor: '#00000000',
        navigationBarContentColor: this.isDark ? '#E6E8EB' : '#1F2329'
      });
      // 把系统栏避让高度交给页面自行留白
      const sysArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('topAvoidPx', sysArea.topRect.height);
      AppStorage.setOrCreate('bottomAvoidPx', navArea.bottomRect.height);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to refresh window style. Cause: %{public}s', JSON.stringify(err));
    }
  }

  // 系统深浅色切换时同步窗口底色
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate');
    this.isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.refreshWindowStyle();
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
