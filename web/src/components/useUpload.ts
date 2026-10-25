// Files dropped or picked, uploaded one after another (POST /files) and then put where they belong (a record, a
// document, the passport's pages) by `attach`. A failure keeps what got through: "Try again" uploads only the files
// still to go and attaches the uploaded ones again (attaching a file twice to the same place is no error), so nothing
// is uploaded or added twice; files dropped after a failure go along with the failed ones, which are never dropped.
// While an upload is on its way, leaving the page waits for it (the tab's closing asks); a failure still to be tried
// again asks before it is left.
import { useCallback, useLayoutEffect, useRef, useState } from 'react';
import type { ApiClient } from '../api/client';
import { uploadFile } from '../api/files';
import type { FileLink } from '../api/types';
import { useLeaveGuard } from './LeaveGuard';

interface Job {
  files: File[];
  uploaded: FileLink[];
}

export interface Upload {
  /** While uploading: how many files are done out of how many. */
  progress: { done: number; total: number } | null;
  /** Why the last try failed. */
  failure: unknown;
  /** A failed job can be tried again. */
  canRetry: boolean;
  /** The files of a failed job, still to be added: a new drop takes them along. */
  waiting: number;
  busy: boolean;
  start: (files: File[]) => Promise<boolean>;
  retry: () => Promise<boolean>;
  dismiss: () => void;
}

export function useUpload(api: ApiClient, attach: (links: FileLink[]) => Promise<void>): Upload {
  const [progress, setProgress] = useState<Upload['progress']>(null);
  const [failure, setFailure] = useState<unknown>(null);
  const pending = useRef<Job | null>(null);
  const [busy, setBusy] = useState(false);
  // The latest `attach`: it may close over data that changed since the upload began.
  const attachRef = useRef(attach);
  useLayoutEffect(() => {
    attachRef.current = attach;
  });

  const run = useCallback(
    async (job: Job): Promise<boolean> => {
      setBusy(true);
      setFailure(null);
      pending.current = job;
      try {
        while (job.uploaded.length < job.files.length) {
          setProgress({ done: job.uploaded.length, total: job.files.length });
          job.uploaded.push(await uploadFile(api, job.files[job.uploaded.length]!));
        }
        setProgress({ done: job.files.length, total: job.files.length });
        await attachRef.current(job.uploaded);
        pending.current = null;
        return true;
      } catch (error) {
        setFailure(error);
        return false;
      } finally {
        setProgress(null);
        setBusy(false);
      }
    },
    [api],
  );

  const failed = failure !== null ? pending.current : null;
  useLeaveGuard(failed !== null, busy);

  return {
    progress,
    failure,
    canRetry: failed !== null,
    waiting: failed?.files.length ?? 0,
    busy,
    // Dropped after a failure: the failed files go first, with what they got done.
    start: (files) =>
      run(failed ? { files: [...failed.files, ...files], uploaded: failed.uploaded } : { files, uploaded: [] }),
    retry: () => (pending.current ? run(pending.current) : Promise.resolve(true)),
    dismiss: () => {
      pending.current = null;
      setFailure(null);
    },
  };
}
