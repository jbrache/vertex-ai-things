# pip install google-auth-oauthlib
from google_auth_oauthlib.flow import Flow

flow = Flow.from_client_secrets_file('client_secret.json',
    scopes=['https://www.googleapis.com/auth/userinfo.email',
            'https://www.googleapis.com/auth/userinfo.profile'
])

flow.redirect_uri = 'https://vertexaisearch.cloud.google.com/oauth-redirect'

authorization_url, state = flow.authorization_url(
    access_type='offline',
    include_granted_scopes='true',
    prompt='consent')
print('OAUTH_AUTH_URI:')
print(authorization_url)
