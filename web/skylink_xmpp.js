(function () {
  'use strict';

  const isLocalWeb =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1';
  const boshUrl = isLocalWeb
    ? 'http://127.0.0.1:8787/bosh'
    : 'https://chat.skylinkonline.net:5443/bosh';
  const uploadService = 'upload.chat.skylinkonline.net';
  let connection = null;
  let currentJid = '';
  let roster = [];
  let messages = [];

  function bareJid(jid) {
    return String(jid || '').split('/')[0].toLowerCase();
  }

  function messageRecord(stanza, archived) {
    let source = stanza;
    const result = stanza.getElementsByTagNameNS('urn:xmpp:mam:2', 'result')[0];
    if (result) {
      const forwarded = result.getElementsByTagNameNS(
        'urn:xmpp:forward:0',
        'forwarded'
      )[0];
      if (forwarded) {
        source = forwarded.getElementsByTagName('message')[0] || source;
      }
    }

    const bodyNode = source.getElementsByTagName('body')[0];
    if (!bodyNode) return null;
    const body = Strophe.getText(bodyNode);
    if (!body) return null;

    const from = bareJid(source.getAttribute('from'));
    const to = bareJid(source.getAttribute('to'));
    let timestamp = new Date();
    const delay = stanza.getElementsByTagNameNS('urn:xmpp:delay', 'delay')[0];
    if (delay && delay.getAttribute('stamp')) {
      const parsed = new Date(delay.getAttribute('stamp'));
      if (!Number.isNaN(parsed.getTime())) timestamp = parsed;
    }

    return {
      id:
        source.getAttribute('id') ||
        result?.getAttribute('id') ||
        `${timestamp.getTime()}-${Math.random()}`,
      from,
      to,
      body,
      side: from === bareJid(currentJid) ? 'me' : 'them',
      status: 'sent',
      created_at: timestamp.toISOString(),
      time: timestamp.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
      }),
      archived: archived === true,
    };
  }

  function storeMessage(stanza, archived) {
    const record = messageRecord(stanza, archived);
    if (!record) return true;
    if (!messages.some((item) => item.id === record.id)) messages.push(record);
    messages.sort((a, b) => a.created_at.localeCompare(b.created_at));
    mergeMessageContacts();
    return true;
  }

  function contactFor(jid) {
    const cleanJid = bareJid(jid);
    let contact = roster.find((item) => item.jid === cleanJid);
    if (!contact) {
      contact = {
        emp_id: cleanJid.split('@')[0],
        jid: cleanJid,
        name: cleanJid.split('@')[0],
        designation: '',
        type: 'chat',
        last: '',
        time: '',
      };
      roster.push(contact);
    }
    return contact;
  }

  function mergeMessageContacts() {
    for (const message of messages) {
      const peer = message.from === currentJid ? message.to : message.from;
      if (
        !peer ||
        peer === currentJid ||
        !peer.endsWith('@chat.skylinkonline.net')
      ) {
        continue;
      }
      const contact = contactFor(peer);
      if (!contact.time || message.created_at >= contact.time) {
        contact.last = message.body;
        contact.time = message.created_at;
      }
    }
    roster.sort((a, b) => String(b.time).localeCompare(String(a.time)));
  }

  function loadVCard(contact) {
    return new Promise((resolve) => {
      const iq = $iq({ type: 'get', to: contact.jid }).c('vCard', {
        xmlns: 'vcard-temp',
      });
      connection.sendIQ(
        iq,
        (result) => {
          const fullName = result.getElementsByTagName('FN')[0];
          const nickname = result.getElementsByTagName('NICKNAME')[0];
          const name = fullName
            ? Strophe.getText(fullName)
            : nickname
            ? Strophe.getText(nickname)
            : '';
          if (name) contact.name = name;
          resolve(contact);
        },
        () => resolve(contact),
        5000
      );
    });
  }

  function loadRoster() {
    return new Promise((resolve, reject) => {
      const iq = $iq({ type: 'get' }).c('query', {
        xmlns: 'jabber:iq:roster',
      });
      connection.sendIQ(
        iq,
        (result) => {
          roster = Array.from(result.getElementsByTagName('item')).map(
            (item) => {
              const jid = bareJid(item.getAttribute('jid'));
              return {
                emp_id: jid.split('@')[0],
                jid,
                name: item.getAttribute('name') || jid.split('@')[0],
                designation: '',
                type: 'chat',
                last: '',
                time: '',
              };
            }
          );
          mergeMessageContacts();
          resolve(roster);
        },
        () => {
          mergeMessageContacts();
          resolve(roster);
        }
      );
    });
  }

  function loadRecentContacts() {
    return new Promise((resolve) => {
      const queryId = `recent-${Date.now()}`;
      const iq = $iq({ type: 'set' })
        .c('query', { xmlns: 'urn:xmpp:mam:2', queryid: queryId })
        .c('x', { xmlns: 'jabber:x:data', type: 'submit' })
        .c('field', { var: 'FORM_TYPE', type: 'hidden' })
        .c('value')
        .t('urn:xmpp:mam:2')
        .up()
        .up()
        .up()
        .c('set', { xmlns: 'http://jabber.org/protocol/rsm' })
        .c('max')
        .t('100');

      connection.sendIQ(
        iq,
        async () => {
          mergeMessageContacts();
          await Promise.all(roster.map(loadVCard));
          resolve(roster);
        },
        () => {
          mergeMessageContacts();
          resolve(roster);
        },
        12000
      );
    });
  }

  window.skylinkXmpp = {
    connect(jid, password) {
      return new Promise((resolve, reject) => {
        if (!window.Strophe) {
          reject(new Error('XMPP library did not load.'));
          return;
        }
        if (connection) connection.disconnect();
        currentJid = bareJid(jid);
        roster = [];
        messages = [];
        connection = new Strophe.Connection(boshUrl);
        connection.rawInput = function () {};
        connection.rawOutput = function () {};
        connection.connect(currentJid, password, async (status) => {
          if (status === Strophe.Status.CONNECTED) {
            connection.addHandler(storeMessage, null, 'message', null, null, null);
            connection.send($pres());
            try {
              await loadRoster();
              await loadRecentContacts();
              resolve(
                JSON.stringify({
                  emp_id: currentJid.split('@')[0],
                  jid: currentJid,
                })
              );
            } catch (error) {
              reject(error);
            }
          } else if (
            status === Strophe.Status.AUTHFAIL ||
            status === Strophe.Status.CONNFAIL
          ) {
            connection = null;
            reject(new Error('Invalid XMPP username or password.'));
          } else if (status === Strophe.Status.ERROR) {
            connection = null;
            reject(new Error('Unable to connect to the XMPP server.'));
          }
        });
      });
    },

    getRoster() {
      if (!connection || !connection.connected) {
        return Promise.reject(new Error('XMPP is not connected.'));
      }
      return loadRoster()
        .then(loadRecentContacts)
        .then((items) => JSON.stringify(items));
    },

    getHistory(withJid) {
      return new Promise((resolve, reject) => {
        if (!connection || !connection.connected) {
          reject(new Error('XMPP is not connected.'));
          return;
        }
        const peer = bareJid(withJid);
        const queryId = `mam-${Date.now()}`;
        let settled = false;
        const finish = () => {
          if (settled) return;
          settled = true;
          const relevant = messages.filter(
            (item) => item.from === peer || item.to === peer
          );
          resolve(JSON.stringify(relevant));
        };
        const mamHandler = connection.addHandler(
          (stanza) => {
            const result = stanza.getElementsByTagNameNS(
              'urn:xmpp:mam:2',
              'result'
            )[0];
            if (!result || result.getAttribute('queryid') !== queryId) {
              return true;
            }
            storeMessage(stanza, true);
            return true;
          },
          null,
          'message',
          null,
          null,
          null
        );
        const iq = $iq({ type: 'set' })
          .c('query', { xmlns: 'urn:xmpp:mam:2', queryid: queryId })
          .c('x', { xmlns: 'jabber:x:data', type: 'submit' })
          .c('field', { var: 'FORM_TYPE', type: 'hidden' })
          .c('value')
          .t('urn:xmpp:mam:2')
          .up()
          .up()
          .c('field', { var: 'with' })
          .c('value')
          .t(peer)
          .up()
          .up()
          .up()
          .c('set', { xmlns: 'http://jabber.org/protocol/rsm' })
          .c('max')
          .t('100');

        connection.sendIQ(
          iq,
          () => {
            connection.deleteHandler(mamHandler);
            finish();
          },
          () => {
            connection.deleteHandler(mamHandler);
            if (messages.some((item) => item.from === peer || item.to === peer)) {
              finish();
            } else {
              reject(new Error('Unable to load message history.'));
            }
          },
          12000
        );
      });
    },

    sendMessage(to, body) {
      if (!connection || !connection.connected) {
        return Promise.reject(new Error('XMPP is not connected.'));
      }
      const peer = bareJid(to);
      const id = connection.getUniqueId('msg');
      const stanza = $msg({ to: peer, type: 'chat', id })
        .c('body')
        .t(String(body))
        .up()
        .c('active', { xmlns: 'http://jabber.org/protocol/chatstates' });
      connection.send(stanza);
      connection.flush();
      messages.push({
        id,
        from: currentJid,
        to: peer,
        body: String(body),
        side: 'me',
        status: 'sent',
        created_at: new Date().toISOString(),
        time: new Date().toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        }),
      });
      return Promise.resolve(JSON.stringify({ status: true, id }));
    },

    requestUploadSlot(filename, size, contentType) {
      return new Promise((resolve, reject) => {
        if (!connection || !connection.connected) {
          reject(new Error('XMPP is not connected.'));
          return;
        }
        const iq = $iq({ type: 'get', to: uploadService })
          .c('request', {
            xmlns: 'urn:xmpp:http:upload:0',
            filename: String(filename),
            size: String(size),
            'content-type': String(contentType || 'application/octet-stream'),
          });
        connection.sendIQ(
          iq,
          (result) => {
            const slot = result.getElementsByTagNameNS(
              'urn:xmpp:http:upload:0',
              'slot'
            )[0];
            const put = slot?.getElementsByTagName('put')[0];
            const get = slot?.getElementsByTagName('get')[0];
            const putUrl = put?.getAttribute('url') || '';
            const getUrl = get?.getAttribute('url') || '';
            if (!putUrl || !getUrl) {
              reject(new Error('Ejabberd returned an invalid upload slot.'));
              return;
            }
            const headers = {};
            for (const header of Array.from(
              put.getElementsByTagName('header')
            )) {
              const name = header.getAttribute('name');
              if (name) headers[name] = Strophe.getText(header);
            }
            resolve(JSON.stringify({ put_url: putUrl, get_url: getUrl, headers }));
          },
          () =>
            reject(
              new Error(
                'Ejabberd file upload is unavailable. Check mod_http_upload and restart ejabberd.'
              )
            ),
          15000
        );
      });
    },

    sendAttachment(to, body, url) {
      if (!connection || !connection.connected) {
        return Promise.reject(new Error('XMPP is not connected.'));
      }
      const peer = bareJid(to);
      const id = connection.getUniqueId('file');
      const stanza = $msg({ to: peer, type: 'chat', id })
        .c('body')
        .t(String(body))
        .up()
        .c('x', { xmlns: 'jabber:x:oob' })
        .c('url')
        .t(String(url));
      connection.send(stanza);
      connection.flush();
      messages.push({
        id,
        from: currentJid,
        to: peer,
        body: String(body),
        side: 'me',
        status: 'sent',
        created_at: new Date().toISOString(),
        time: new Date().toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        }),
      });
      return Promise.resolve(JSON.stringify({ status: true, id }));
    },

    disconnect() {
      if (connection) connection.disconnect();
      connection = null;
      currentJid = '';
      roster = [];
      messages = [];
    },
  };
})();
