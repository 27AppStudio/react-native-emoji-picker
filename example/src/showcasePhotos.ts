// Photos from Unsplash (unsplash.com, Unsplash License), hotlinked as its API guidelines ask.
// Credited in the README under the screenshots. Picked with the Unsplash API search.
export type Photo = { id: string; url: string; by: string; page: string };

export const sized = (p: Photo, w: number, h = w) =>
  `${p.url}&w=${w}&h=${h}&fit=crop&q=80&auto=format`;

export const CHAT: Photo = {
  id: 'g0Qdolm3K14',
  url: 'https://images.unsplash.com/photo-1491378630646-3440efa57c3b?ixid=M3wxMTM4ODM5fDB8MXxzZWFyY2h8MXx8YmVhY2glMjBzdW1tZXJ8ZW58MXx8fHwxNzk1MTA3ODcyfDA&ixlib=rb-4.1.0',
  by: 'Mink Mingle',
  page: 'https://unsplash.com/photos/seashore-under-clear-blue-sky-during-daytime-g0Qdolm3K14',
};
