import { picker, fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Db } from './Db';
import { BackupRecord, RecordItem } from './Types';
import { todayStr } from './DateUtil';

interface BackupFile {
  app: string;
  version: number;
  exported_at: string;
  records: Array<BackupRecord>;
}

export interface ImportResult {
  added: number;
  skipped: number;
}

// 备份与恢复：导出为 JSON 文件（用户自选位置），导入时按内容去重合并
export class Backup {
  // 导出全部记录，返回记录数；用户取消返回 null
  static async exportAll(): Promise<number | null> {
    const docPicker = new picker.DocumentViewPicker();
    const opts = new picker.DocumentSaveOptions();
    opts.newFileNames = ['日记备份_' + todayStr() + '.json'];
    const uris: Array<string> = await docPicker.save(opts);
    if (uris === undefined || uris.length === 0) {
      return null;
    }
    const raw: Array<BackupRecord> = await Db.getAllRaw();
    const data: BackupFile = {
      app: 'diary',
      version: 1,
      exported_at: todayStr(),
      records: raw
    };
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    fileIo.writeSync(file.fd, JSON.stringify(data));
    fileIo.closeSync(file.fd);
    return raw.length;
  }

  // 从备份文件导入（去重合并），用户取消返回 null
  static async importMerge(): Promise<ImportResult | null> {
    const docPicker = new picker.DocumentViewPicker();
    const uris: Array<string> = await docPicker.select(new picker.DocumentSelectOptions());
    if (uris === undefined || uris.length === 0) {
      return null;
    }
    const file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(file.fd);
    const buf = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buf);
    fileIo.closeSync(file.fd);
    const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
    const data = JSON.parse(text) as BackupFile;
    if (data.records === undefined || data.records === null) {
      throw new Error('bad backup file');
    }
    const res: ImportResult = { added: 0, skipped: 0 };
    const base: number = Date.now();
    for (let i = 0; i < data.records.length; i++) {
      const r = data.records[i];
      const dup: boolean = await Db.recordExists(r.date, r.type, r.content, r.amount);
      if (dup) {
        res.skipped += 1;
      } else {
        const it: RecordItem = { id: 0, date: r.date, type: r.type, content: r.content, amount: r.amount };
        await Db.insertRecord(it, base + i);
        res.added += 1;
      }
    }
    return res;
  }
}
