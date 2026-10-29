import React from 'react';

// Walkthrough longo: iframe lazy para link não listado do YouTube/Drive.
// Acesso fora do IAP: nunca mostrar dado real de cliente.
export default function VideoEmbed({src, title}) {
  return (
    <div style={{position: 'relative', paddingBottom: '56.25%', height: 0, marginBottom: '1rem'}}>
      <iframe
        src={src}
        title={title}
        loading="lazy"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerPolicy="strict-origin-when-cross-origin"
        allowFullScreen
        style={{position: 'absolute', inset: 0, width: '100%', height: '100%', border: 0}}
      />
    </div>
  );
}
