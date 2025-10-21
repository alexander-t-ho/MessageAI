// Lambda Function: Login
// Authenticates a user and returns JWT tokens

const { CognitoIdentityProviderClient, InitiateAuthCommand, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'us-east-1' });
const ddbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(ddbClient);

exports.handler = async (event) => {
    console.log('Login request:', JSON.stringify(event, null, 2));
    
    // Parse request body
    const body = JSON.parse(event.body);
    const { email, password } = body;
    
    // Validate input
    if (!email || !password) {
        return {
            statusCode: 400,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Missing required fields',
                message: 'Email and password are required'
            })
        };
    }
    
    const APP_CLIENT_ID = process.env.APP_CLIENT_ID;
    const USERS_TABLE = process.env.USERS_TABLE;
    
    try {
        // Authenticate with Cognito
        const authCommand = new InitiateAuthCommand({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: APP_CLIENT_ID,
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password
            }
        });
        
        const authResult = await cognito.send(authCommand);
        
        console.log('Authentication successful');
        
        // Get user attributes
        const accessToken = authResult.AuthenticationResult.AccessToken;
        const getUserCommand = new GetUserCommand({
            AccessToken: accessToken
        });
        const userInfo = await cognito.send(getUserCommand);
        
        const userId = userInfo.Username;
        const userName = userInfo.UserAttributes.find(attr => attr.Name === 'name')?.Value || 'User';
        
        // Update user's last seen in DynamoDB
        try {
            await dynamodb.send(new UpdateCommand({
                TableName: USERS_TABLE,
                Key: { userId: userId },
                UpdateExpression: 'SET lastSeen = :now, isOnline = :online',
                ExpressionAttributeValues: {
                    ':now': new Date().toISOString(),
                    ':online': true
                }
            }));
            
            console.log('Updated user status in DynamoDB');
        } catch (dbError) {
            console.error('Failed to update DynamoDB, but login successful:', dbError);
            // Don't fail login if DynamoDB update fails
        }
        
        // Return success response with tokens
        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                success: true,
                userId: userId,
                email: email,
                name: userName,
                tokens: {
                    accessToken: authResult.AuthenticationResult.AccessToken,
                    idToken: authResult.AuthenticationResult.IdToken,
                    refreshToken: authResult.AuthenticationResult.RefreshToken,
                    expiresIn: authResult.AuthenticationResult.ExpiresIn
                },
                message: 'Login successful'
            })
        };
        
    } catch (error) {
        console.error('Login error:', error);
        
        // Handle specific Cognito errors
        let errorMessage = 'Login failed';
        let statusCode = 401;
        
        if (error.code === 'NotAuthorizedException') {
            errorMessage = 'Incorrect email or password';
        } else if (error.code === 'UserNotFoundException') {
            errorMessage = 'No account found with this email';
        } else if (error.code === 'UserNotConfirmedException') {
            errorMessage = 'Please verify your email before logging in';
            statusCode = 403;
        } else if (error.code === 'TooManyRequestsException') {
            errorMessage = 'Too many login attempts. Please try again later.';
            statusCode = 429;
        } else {
            statusCode = 500;
        }
        
        return {
            statusCode: statusCode,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: error.code || 'LoginError',
                message: errorMessage,
                details: error.message
            })
        };
    }
};

