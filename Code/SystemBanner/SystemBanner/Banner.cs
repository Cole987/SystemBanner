//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
using System;
using System.Windows.Forms;

namespace SystemBanner
{
    public partial class Banner : Form
    {
        public Banner(int instanceScreen, bool instancePosition)
        {
            BuildBanner(instanceScreen, instancePosition);
            if (!Program.secureDesktop) //there is no shell (and so no AppBar) on the Winlogon desktop
            {
                BuildAppBar(instanceScreen, instancePosition);
            }

        }
        protected override void WndProc(ref Message m)
        {
            //on logoff Windows asks every window on WinSta0 to close, the Winlogon banner must survive it to show on the logon screen that follows
            if (Program.secureDesktop && (m.Msg == 0x0011 /* WM_QUERYENDSESSION */ || m.Msg == 0x0016 /* WM_ENDSESSION */))
            {
                m.Result = (IntPtr)1; //"ok to end", but do not close anything
                return;
            }
            base.WndProc(ref m);
        }
        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            //refuse user close attempts (alt+f4, etc.), only SystemBanner or Windows shutdown may close a banner
            if (e.CloseReason == CloseReason.UserClosing && !Program.closingBanners)
            {
                e.Cancel = true;
            }
            base.OnFormClosing(e);
        }
        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            if (!Program.secureDesktop)
            {
                KillAppBar();
            }
            base.OnFormClosed(e);
        }
    }
}
