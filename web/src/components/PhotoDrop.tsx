// A pet's photo that takes a new one: dragged onto it from the computer, or picked with "Add photo". The file is
// checked here first (a JPEG, PNG or WebP up to 15 MB: the server's rules), so a wrong one is explained before it
// travels; what happens with a good one is the page's business (upload at once, or on "Save").
import { useRef, useState, type DragEvent } from 'react';
import { photoProblem } from '../api/files';
import type { FileLink } from '../api/types';
import { useI18n } from '../i18n/i18n';
import { Icon } from './Icon';
import { PetAvatar } from './PetAvatar';
import { Spinner } from './ui';

export function PhotoDrop({
  name,
  photo,
  preview,
  editable,
  busy = false,
  error,
  onPick,
  onRemove,
}: {
  name: string;
  /** The saved photo. */
  photo: FileLink | null;
  /** A picked photo not saved yet (an object URL), shown instead of the saved one. */
  preview?: string | null;
  /** Helpers see the photo but don't change it. */
  editable: boolean;
  busy?: boolean;
  /** Why the last upload failed. */
  error?: string | null;
  onPick: (file: File) => void;
  onRemove: () => void;
}) {
  const { t } = useI18n();
  const input = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const hasPhoto = !!preview || !!photo;

  function take(file: File | undefined) {
    if (!file) return;
    const wrong = photoProblem(file);
    setProblem(wrong ? t[wrong] : null);
    if (!wrong) onPick(file);
  }

  // Only a drag that carries files is taken: a dragged link or text goes its own way.
  const carriesFiles = (event: DragEvent) => Array.from(event.dataTransfer.types).includes('Files');

  const dropHandlers = editable
    ? {
        onDragOver: (event: DragEvent) => {
          if (!carriesFiles(event) || busy) return;
          event.preventDefault();
          event.dataTransfer.dropEffect = 'copy';
          setDragging(true);
        },
        onDragLeave: (event: DragEvent) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setDragging(false);
        },
        onDrop: (event: DragEvent) => {
          event.preventDefault();
          setDragging(false);
          if (!busy) take(event.dataTransfer.files[0]);
        },
      }
    : {};

  const shownError = problem ?? error;
  return (
    <div className={`photo-drop${dragging ? ' is-dragging' : ''}`} aria-busy={busy || undefined} {...dropHandlers}>
      <div className="photo-drop-picture">
        {preview ? (
          <span className="avatar avatar--xl">
            <img src={preview} alt="" />
          </span>
        ) : (
          <PetAvatar name={name} photo={photo} size="xl" />
        )}
        {busy && (
          <span className="photo-drop-busy" role="status" aria-label={t.petPhotoUploading}>
            <Spinner />
          </span>
        )}
        {dragging && <span className="photo-drop-target">{t.petPhotoDrop}</span>}
      </div>
      {editable && (
        <>
          <div className="photo-drop-actions">
            <button
              type="button"
              className="button button--secondary"
              onClick={() => input.current?.click()}
              disabled={busy}
            >
              <Icon name="photo_camera" size={18} />
              {hasPhoto ? t.petPhotoChange : t.petPhotoAdd}
            </button>
            {hasPhoto && (
              <button
                type="button"
                className="button button--ghost button--danger-text"
                onClick={onRemove}
                disabled={busy}
              >
                <Icon name="delete" size={18} />
                {t.petPhotoRemove}
              </button>
            )}
          </div>
          <p className="field-hint">{t.petPhotoDragHint}</p>
          <input
            ref={input}
            className="visually-hidden"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            tabIndex={-1}
            aria-hidden="true"
            onChange={(event) => {
              take(event.target.files?.[0]);
              // The same file again is a new choice.
              event.target.value = '';
            }}
          />
        </>
      )}
      {shownError && (
        <p className="field-error" role="alert">
          <Icon name="error" size={16} />
          {shownError}
        </p>
      )}
    </div>
  );
}
