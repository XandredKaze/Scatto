using System;
using System.Net;
using System.Net.Sockets;

namespace CupheadOnlineCoop.Net
{
    /// <summary>
    /// Socket UDP non bloccante, usato solo dal thread principale di Unity.
    /// Niente thread separati: a ogni frame si svuota la coda con <see cref="TryReceive"/>.
    /// </summary>
    public sealed class UdpTransport : IDisposable
    {
        private readonly Socket socket;
        private readonly byte[] recvBuffer = new byte[4096];

        public EndPoint Remote { get; set; }

        public UdpTransport(int bindPort)
        {
            socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
            socket.Blocking = false;
            TryDisableConnReset();
            socket.Bind(new IPEndPoint(IPAddress.Any, bindPort));
        }

        // Su Windows un pacchetto ICMP "port unreachable" fa fallire le ReceiveFrom successive
        // con WSAECONNRESET. Questo IOCTL lo disattiva (se il runtime lo supporta).
        private void TryDisableConnReset()
        {
            try
            {
                const int SIO_UDP_CONNRESET = -1744830452;
                socket.IOControl(SIO_UDP_CONNRESET, new byte[] { 0 }, null);
            }
            catch (Exception) { /* non supportato: gestiamo l'eccezione in TryReceive */ }
        }

        public static EndPoint Resolve(string host, int port)
        {
            IPAddress ip;
            if (!IPAddress.TryParse(host, out ip))
            {
                ip = null;
                foreach (IPAddress a in Dns.GetHostAddresses(host))
                    if (a.AddressFamily == AddressFamily.InterNetwork) { ip = a; break; }
                if (ip == null) throw new Exception("Impossibile risolvere l'host '" + host + "'");
            }
            return new IPEndPoint(ip, port);
        }

        public void Send(byte[] data, int length)
        {
            Send(data, length, Remote);
        }

        public void Send(byte[] data, int length, EndPoint to)
        {
            if (to == null) return;
            try { socket.SendTo(data, 0, length, SocketFlags.None, to); }
            catch (SocketException) { /* UDP: un pacchetto perso non è un problema */ }
        }

        public bool TryReceive(out byte[] data, out int length, out EndPoint from)
        {
            data = recvBuffer;
            length = 0;
            from = null;
            while (true)
            {
                try
                {
                    if (socket.Available <= 0) return false;
                    EndPoint ep = new IPEndPoint(IPAddress.Any, 0);
                    length = socket.ReceiveFrom(recvBuffer, ref ep);
                    from = ep;
                    return true;
                }
                catch (SocketException e)
                {
                    if (e.SocketErrorCode == SocketError.WouldBlock) return false;
                    if (e.SocketErrorCode == SocketError.ConnectionReset) continue;
                    if (e.SocketErrorCode == SocketError.MessageSize) continue;
                    throw;
                }
            }
        }

        public void Dispose()
        {
            try { socket.Close(); } catch (Exception) { }
        }
    }
}
