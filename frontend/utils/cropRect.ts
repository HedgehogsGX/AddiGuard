export type Rect = { x: number; y: number; width: number; height: number };

/** Maps a frame in the camera view to pixels in a photo rendered with aspect-ratio cover. */
export function frameToPhotoCrop(frame: Rect, camera: Rect, photo: { width: number; height: number }): Rect {
  if (![...Object.values(frame), ...Object.values(camera), ...Object.values(photo)].every(Number.isFinite)
    || camera.width <= 0 || camera.height <= 0 || photo.width <= 0 || photo.height <= 0
    || frame.width <= 0 || frame.height <= 0) {
    throw new Error('Camera frame is not ready. Please try again.');
  }
  const scale = Math.max(camera.width / photo.width, camera.height / photo.height);
  const renderedWidth = photo.width * scale;
  const renderedHeight = photo.height * scale;
  const offsetX = (camera.width - renderedWidth) / 2;
  const offsetY = (camera.height - renderedHeight) / 2;
  const left = Math.max(0, Math.min(photo.width, (frame.x - camera.x - offsetX) / scale));
  const top = Math.max(0, Math.min(photo.height, (frame.y - camera.y - offsetY) / scale));
  const right = Math.max(left, Math.min(photo.width, (frame.x + frame.width - camera.x - offsetX) / scale));
  const bottom = Math.max(top, Math.min(photo.height, (frame.y + frame.height - camera.y - offsetY) / scale));
  const x = Math.round(left);
  const y = Math.round(top);
  const width = Math.round(right) - x;
  const height = Math.round(bottom) - y;
  if (width <= 0 || height <= 0) throw new Error('Scan frame is outside the photo.');
  return { x, y, width, height };
}
