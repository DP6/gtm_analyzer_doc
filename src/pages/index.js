import {Redirect} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';

// Sem home própria (plano §4): entra direto no guia do usuário.
export default function Home() {
  return <Redirect to={useBaseUrl('/docs/documentacao-do-projeto/visao-geral-e-arquitetura/visao-geral')} />;
}
