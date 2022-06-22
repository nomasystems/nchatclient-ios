// Copyright © 2020 Nomasystems S.L. All rights reserved.

enum BOSHState {
    case disconnected, connecting, connected
}

enum BOSHRequestState {
    case suspended, running, completed, cancelled, failed
}
