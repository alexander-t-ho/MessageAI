// Lambda Function: Signup
// Creates a new user account in Cognito

const { CognitoIdentityProviderClient, SignUpCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'us-east-1' });
const ddbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(ddbClient);

exports.handler = async (event) => {
    console.log('Signup request:', JSON.stringify(event, null, 2));
    
    // Parse request body
    const body = JSON.parse(event.body);
    const { email, password, name } = body;
    
    // Validate input
    if (!email || !password || !name) {
        return {
            statusCode: 400,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: 'Missing required fields',
                message: 'Email, password, and name are required'
            })
        };
    }
    
    const USER_POOL_ID = process.env.USER_POOL_ID;
    const APP_CLIENT_ID = process.env.APP_CLIENT_ID;
    const USERS_TABLE = process.env.USERS_TABLE;
    
    try {
        // Create user in Cognito
        const signUpCommand = new SignUpCommand({
            ClientId: APP_CLIENT_ID,
            Username: email,
            Password: password,
            UserAttributes: [
                {
                    Name: 'email',
                    Value: email
                },
                {
                    Name: 'name',
                    Value: name
                }
            ]
        });
        
        const signUpResult = await cognito.send(signUpCommand);
        const userId = signUpResult.UserSub;
        
        console.log('User created in Cognito:', userId);
        
        // Create user profile in DynamoDB
        const userProfile = {
            userId: userId,
            email: email,
            name: name,
            createdAt: new Date().toISOString(),
            isOnline: false,
            lastSeen: new Date().toISOString()
        };
        
        await dynamodb.send(new PutCommand({
            TableName: USERS_TABLE,
            Item: userProfile
        }));
        
        console.log('User profile created in DynamoDB');
        
        // Return success response
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
                name: name,
                message: 'User created successfully. Please check your email to verify your account.'
            })
        };
        
    } catch (error) {
        console.error('Signup error:', error);
        
        // Handle specific Cognito errors
        let errorMessage = 'Failed to create account';
        let statusCode = 500;
        
        if (error.code === 'UsernameExistsException') {
            errorMessage = 'An account with this email already exists';
            statusCode = 400;
        } else if (error.code === 'InvalidPasswordException') {
            errorMessage = 'Password does not meet requirements';
            statusCode = 400;
        } else if (error.code === 'InvalidParameterException') {
            errorMessage = 'Invalid email or password format';
            statusCode = 400;
        }
        
        return {
            statusCode: statusCode,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                error: error.code || 'SignupError',
                message: errorMessage,
                details: error.message
            })
        };
    }
};

