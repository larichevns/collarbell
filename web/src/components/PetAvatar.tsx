// The pet's photo in a circle; without one (or while it can't load), the pet's initial on a calm blue-grey circle
// (`avatar`, `on-avatar`). Pets have no colour of their own: green and yellow in the app mean "done" and "soon".
// Decorative: the pet's name is always next to it.
import { useState } from 'react';
import { fileUrl } from '../api/files';
import type { FileLink } from '../api/types';

type AvatarSize = 'sm' | 'md' | 'lg' | 'xl';

/** The first letter of the name, upper case; "?" for no name yet. */
function initialOf(name: string): string {
  const first = [...name.trim()][0];
  return first ? first.toUpperCase() : '?';
}

export function PetAvatar({
  name,
  photo,
  size = 'md',
}: {
  name: string;
  photo?: FileLink | null;
  size?: AvatarSize;
}) {
  // The link a photo failed to load from: its initial instead, until a fresh link comes.
  const [failed, setFailed] = useState<string | null>(null);
  const isPicture = photo && photo.contentType.startsWith('image/');
  const url = isPicture ? fileUrl(photo, size !== 'xl') : null;
  return (
    <span className={`avatar avatar--${size}`} aria-hidden="true">
      {url && url !== failed ? (
        <img src={url} alt="" loading="lazy" onError={() => setFailed(url)} />
      ) : (
        initialOf(name)
      )}
    </span>
  );
}
