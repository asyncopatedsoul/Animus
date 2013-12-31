//
//  MyScene.m
//  SpaceShooter
//
//  Created by Tony Dahbura on 9/9/13.
//  Copyright (c) 2013 fullmoonmanor. All rights reserved.
//

@import AVFoundation;
@import CoreMotion;

#import "MyScene.h"
#import "FMMParallaxNode.h"


// Add to top of file
#define kNumAsteroids   15
#define kNumLasers      5
#define kNumSpiritCollectibles 10

typedef enum {
    kEndReasonWin,
    kEndReasonLose
} EndReason;

@implementation MyScene
{
    SKNode *node;
    
    SKSpriteNode *_animusRoot;
    SKSpriteNode *_animusSprite;
    SKSpriteNode *_animusEnergyMeter;
    SKSpriteNode *_animusStaminaMeter;
    NSTimeInterval *_animusReleasedDuration;
    float _animusEnergyCount;
    float _animusStaminaCount;
    
    SKSpriteNode *_playerUIRoot;
    SKSpriteNode *_playerHealthMeter;
    SKSpriteNode *_playerSpiritMeter;
    
    SKSpriteNode *_playerRoot;
    SKSpriteNode *_playerSprite;
    SKSpriteNode *_playerBasicAttack;
    SKSpriteNode *_playerActivateTouchArea;
    float _playerHealthCount;
    float _playerHealthMax;
    
    NSMutableArray *_spiritCollectibles;
    float _playerSpiritCount;
    float _playerSpiritMax;
    float _specialAttackSpiritCost;
    float _cumulativeSpiritsCollected;
    
    
    FMMParallaxNode *_parallaxNodeBackgrounds;
    FMMParallaxNode *_parallaxSpaceDust;
    
    CMMotionManager *_motionManager;
    
    bool _playerFacingRight;
    bool _playerSpecialAttackIsReady;
    
    NSMutableArray *_enemies;
    int _nextAsteroid;
    double _nextAsteroidSpawn;
    
    NSMutableArray *_playerSpriteLasers;
    int _nextShipLaser;

    
    int _lives;
    double _gameOverTime;
    bool _gameOver;
    
    AVAudioPlayer *_backgroundAudioPlayer;

    
}


-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        NSLog(@"SKScene:initWithSize %f x %f",size.width,size.height);
        
        self.backgroundColor = [SKColor blackColor];

        //Define our physics body around the screen - used by our ship to not bounce off the screen
        self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];

#pragma mark - Game Backgrounds
        NSArray *parallaxBackgroundNames = @[@"bg_galaxy.png", @"bg_planetsunrise.png",
                                             @"bg_spacialanomaly.png", @"bg_spacialanomaly2.png"];
        CGSize planetSizes = CGSizeMake(200.0, 200.0);
        _parallaxNodeBackgrounds = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackgroundNames
                                                                              size:planetSizes
                                                              pointsPerSecondSpeed:10.0];
        _parallaxNodeBackgrounds.position = CGPointMake(size.width/2.0, size.height/2.0);
        [_parallaxNodeBackgrounds randomizeNodesPositions];
        [self addChild:_parallaxNodeBackgrounds];

        //Bring on the space dust
        NSArray *parallaxBackground2Names = @[@"bg_front_spacedust.png",@"bg_front_spacedust.png"];
        _parallaxSpaceDust = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackground2Names
                                                                    size:size
                                                    pointsPerSecondSpeed:25.0];
        _parallaxSpaceDust.position = CGPointMake(0, 0);
        [self addChild:_parallaxSpaceDust];
            
#pragma mark - Setup Sprite for the player
        //Create space sprite, setup position on left edge centered on the screen, and add to Scene
        _playerRoot = [SKSpriteNode spriteNodeWithColor:[UIColor blackColor] size:CGSizeMake(40.0, 10.0)];
        _playerRoot.name = @"playerBase";
        _playerRoot.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
        _playerRoot.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize: CGSizeMake(40.0, 10.0)];
        _playerRoot.physicsBody.allowsRotation = NO;
        _playerRoot.physicsBody.dynamic = YES;
        _playerRoot.physicsBody.affectedByGravity = NO;
        _playerRoot.physicsBody.mass = 0.02;
        
        //enlarged area for touching player
        //i.e. for activating special attack
        _playerActivateTouchArea = [SKSpriteNode spriteNodeWithColor:[UIColor blueColor] size:CGSizeMake(60.0, 60.0)];
        _playerActivateTouchArea.position = CGPointMake(0.0, 30.0);
        _playerActivateTouchArea.name = @"activateTouchArea";
        _playerActivateTouchArea.hidden = YES;
        
        _playerSprite = [SKSpriteNode spriteNodeWithImageNamed:@"SpaceFlier_sm_1.png"];
        _playerSprite.name = @"player";
        _playerSprite.position = CGPointMake(0.0,_playerSprite.frame.size.height/2);
        
        _playerFacingRight = YES;
        
        _playerBasicAttack = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(40.0, 30.0)];
        _playerBasicAttack.hidden = YES;
        _playerBasicAttack.name = @"playerBasicAttack";
        
        [_playerRoot addChild:_playerActivateTouchArea];
        [_playerRoot addChild:_playerBasicAttack];
        [_playerRoot addChild:_playerSprite];
        [self addChild:_playerRoot];
        
#pragma mark - Setup Ghost ally
        
        _animusRoot = [SKSpriteNode spriteNodeWithColor:[UIColor blackColor] size:CGSizeMake(40.0, 10.0)];
        _animusRoot.name = @"animus";
        //set position at player when ghost ally appears
        _animusRoot.hidden = YES;
        /*
        _animusRoot.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize: CGSizeMake(40.0, 10.0)];
        _animusRoot.physicsBody.allowsRotation = NO;
        _animusRoot.physicsBody.dynamic = YES;
        _animusRoot.physicsBody.affectedByGravity = NO;
        _animusRoot.physicsBody.mass = 0.02;
        */
        _animusSprite = [SKSpriteNode spriteNodeWithColor:[UIColor greenColor] size:CGSizeMake(80.0,80.0)];
        _animusSprite.position = CGPointMake(0.0,_animusSprite.frame.size.height/2);
        
        [_animusRoot addChild:_animusSprite];
        [self addChild:_animusRoot];
        
#pragma mark - Setup the asteroids
        _enemies = [[NSMutableArray alloc] initWithCapacity:kNumAsteroids];
        for (int i = 0; i < kNumAsteroids; ++i) {
            
            SKSpriteNode *enemyRoot = [SKSpriteNode spriteNodeWithColor:[UIColor redColor] size:CGSizeMake(40.0, 10.0)];
            enemyRoot.hidden = YES;
            
            enemyRoot.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize: enemyRoot.frame.size];
            enemyRoot.physicsBody.allowsRotation = NO;
            enemyRoot.physicsBody.dynamic = YES;
            enemyRoot.physicsBody.affectedByGravity = NO;
            enemyRoot.physicsBody.mass = 0.1;
           
            //set custom properties of enemy
            enemyRoot.userData = [[NSMutableDictionary alloc] init];
            [enemyRoot.userData setValue:[NSNumber numberWithFloat:4.0] forKey:@"health"];
            
            SKSpriteNode *enemySprite = [SKSpriteNode spriteNodeWithImageNamed:@"asteroid"];
            [enemySprite setXScale:0.5];
            [enemySprite setYScale:0.5];
            enemySprite.position = CGPointMake(0.0, enemySprite.frame.size.height/2);
            
            SKSpriteNode *enemyAttackArea = [SKSpriteNode spriteNodeWithColor:[UIColor grayColor] size:CGSizeMake(60.0*2, 30.0)];
            enemyAttackArea.name = @"enemyAttackRange";
            [enemyRoot addChild: enemyAttackArea];
            
            SKSpriteNode *enemyBasicAttack = [SKSpriteNode spriteNodeWithColor:[UIColor redColor] size:CGSizeMake(50.0,30.0)];
            enemyBasicAttack.name = @"enemyBasicAttack";
            [enemyRoot addChild:enemyBasicAttack];
            
            [_enemies addObject:enemyRoot];
            [enemyRoot addChild:enemySprite];
            [self addChild:enemyRoot];
        }
        
#pragma mark - Setup the lasers
        /*
        _playerSpriteLasers = [[NSMutableArray alloc] initWithCapacity:kNumLasers];
        for (int i = 0; i < kNumLasers; ++i) {
            SKSpriteNode *shipLaser = [SKSpriteNode spriteNodeWithImageNamed:@"laserbeam_blue"];
            //SKSpriteNode *shipLaser = [SKSpriteNode spriteNodeWithTexture:laserTexture];
            [shipLaser setYScale:4.0];
            shipLaser.hidden = YES;
            [_playerSpriteLasers addObject:shipLaser];
            //[self addChild:shipLaser];
            [_playerSprite addChild:shipLaser];
        }
        */
#pragma mark - Setup UI overlay
        _playerHealthMax = 100.0;
        _playerSpiritMax = 30.0;
        _specialAttackSpiritCost = 30.0;
        _playerUIRoot = [SKSpriteNode spriteNodeWithColor:[UIColor clearColor] size:CGSizeMake(self.frame.size.width, self.frame.size.height)];
        _playerUIRoot.position = CGPointMake(0.0, 5.0);
        _playerHealthMeter = [SKSpriteNode spriteNodeWithColor:[UIColor greenColor] size:CGSizeMake(self.frame.size.width, 5.0)];
        _playerHealthMeter.position = CGPointMake(0.0, 0.0);
        _playerSpiritMeter = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(0.0, 5.0)];
        _playerSpiritMeter.position = CGPointMake(0.0, 5.0);
        
        [_playerUIRoot addChild:_playerHealthMeter];
        [_playerUIRoot addChild:_playerSpiritMeter];
        [self addChild:_playerUIRoot];
        
#pragma mark - Setup the Accelerometer to move the ship
        _motionManager = [[CMMotionManager alloc] init];
        
#pragma mark - Setup spirit collectibles
         _spiritCollectibles = [[NSMutableArray alloc] initWithCapacity:kNumAsteroids];
            
#pragma mark - Setup the stars to appear as particles
        //Add particles
        [self addChild:[self loadEmitterNode:@"stars1"]];
        [self addChild:[self loadEmitterNode:@"stars2"]];
        [self addChild:[self loadEmitterNode:@"stars3"]];
        
        [self startBackgroundMusic];
#pragma mark - Start the actual game
        [self startTheGame];
    }
    return self;
}


- (SKEmitterNode *)loadEmitterNode:(NSString *)emitterFileName
{
    NSString *emitterPath = [[NSBundle mainBundle] pathForResource:emitterFileName ofType:@"sks"];
    SKEmitterNode *emitterNode = [NSKeyedUnarchiver unarchiveObjectWithFile:emitterPath];
    
    //do some view specific tweaks
    emitterNode.particlePosition = CGPointMake(self.size.width/2.0, self.size.height/2.0);
    emitterNode.particlePositionRange = CGVectorMake(self.size.width+100, self.size.height);
    
    return emitterNode;
    
}


- (void)didMoveToView:(SKView *)view
{
    
    
}


#pragma mark - Start the Game
- (void)startTheGame
{
    _lives = 3;
    double curTime = CACurrentMediaTime();
    _gameOverTime = curTime + 30.0;
    _nextAsteroidSpawn = 0;
    _gameOver = NO;
    
    for (SKSpriteNode *enemy in _enemies) {
        enemy.hidden = YES;
    }
    
    for (SKSpriteNode *laser in _playerSpriteLasers) {
        laser.hidden = YES;
    }
    _playerSprite.hidden = NO;
    //reset ship position for new game
    _playerRoot.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
    
    //setup to handle accelerometer readings using CoreMotion Framework
    [self startMonitoringAcceleration];

}


- (void)startMonitoringAcceleration
{
    if (_motionManager.accelerometerAvailable) {
        [_motionManager startAccelerometerUpdates];
        NSLog(@"accelerometer updates on...");
    }
}

- (void)stopMonitoringAcceleration
{
    if (_motionManager.accelerometerAvailable && _motionManager.accelerometerActive) {
        [_motionManager stopAccelerometerUpdates];
        NSLog(@"accelerometer updates off...");
    }
}

- (void)updateShipPositionFromMotionManager
{
    CMAccelerometerData* data = _motionManager.accelerometerData;
    
    //NSLog(@"acceleration value x,y:\n %f, %f",data.acceleration.x,data.acceleration.y);
    
    // NSLog(@"velocity = %f, %f",_playerSprite.physicsBody.velocity.dx,_playerSprite.physicsBody.velocity.dy);
    
    float speedMultiplierX;
    float speedMultiplierY;
    
    float yInput;
    float xInput;
    
    float absoluteInputX = (data.acceleration.x>0)?data.acceleration.x:data.acceleration.x*-1.0;
    float absoluteInputY = (data.acceleration.y>0)?data.acceleration.y:data.acceleration.y*-1.0;
    
    
    speedMultiplierY = 150.0;
    speedMultiplierX = 100.0*-1.0;
    
    float yInputLowerLimit = 0.1;
    float xInputLowerLimit = 0.1;

    //_playerSprite.physicsBody.linearDamping = 1.0;
    
    //how to stop on a dime?
    //when input direction is opposite of velocity direction, set velocity to 0
    
    //NSLog(@"horizontal velocity vs input: \n %f, %f",_playerSprite.physicsBody.velocity.dx,data.acceleration.y);
    if ( (_playerRoot.physicsBody.velocity.dx>0.0 && data.acceleration.y<0.0) || (_playerRoot.physicsBody.velocity.dx<0.0 && data.acceleration.y>0.0) )
    {
        _playerRoot.physicsBody.velocity = CGVectorMake(0.0,_playerRoot.physicsBody.velocity.dy);

    }
    
    //NSLog(@"vertical velocity vs input: \n %f, %f",_playerSprite.physicsBody.velocity.dy,data.acceleration.x);

    if ( (_playerRoot.physicsBody.velocity.dy<0.0 && data.acceleration.x<0.0) || (_playerRoot.physicsBody.velocity.dy>0.0 && data.acceleration.x>0.0) )
    {
        _playerRoot.physicsBody.velocity = CGVectorMake(_playerRoot.physicsBody.velocity.dx,0.0);

    }
    

    if (absoluteInputY<yInputLowerLimit)
    {
        yInput = 0.0;
        
    }
    else
    {
        if (data.acceleration.y>0.0)
        {
            yInput = 1.0;
            _playerFacingRight = YES;
        }
        else
        {
            yInput =  -1.0;
            _playerFacingRight = NO;
        }
    }
    
    if (absoluteInputX<xInputLowerLimit){
        xInput = 0.0;
    } else {
        xInput = (data.acceleration.x>0.0) ? 1.0 : -1.0;
    }
    
    //make fixed-speed movement like input from arcade joystick, jerky and precise
    _playerRoot.physicsBody.velocity = CGVectorMake(yInput*speedMultiplierY,xInput*speedMultiplierX);
    //[_playerSprite.physicsBody applyForce:CGVectorMake(data.acceleration.y*speedMultiplierY, -1.0*data.acceleration.x*speedMultiplierX)];
    
    
    if ( (_playerFacingRight && _playerRoot.xScale<0) || (!_playerFacingRight && _playerRoot.xScale>0))
        _playerRoot.xScale = _playerRoot.xScale*-1.0;
    
}


- (void)startBackgroundMusic
{
    NSError *err;
    NSURL *file = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SpaceGame.caf" ofType:nil]];
    _backgroundAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&err];
    if (err) {
        NSLog(@"error in audio play %@",[err userInfo]);
        return;
    }
    [_backgroundAudioPlayer prepareToPlay];
    
    // this will play the music infinitely
    _backgroundAudioPlayer.numberOfLoops = -1;
    [_backgroundAudioPlayer setVolume:1.0];
    [_backgroundAudioPlayer play];
}

- (void) applyDamage: (float)attackDamage toEnemy:(SKSpriteNode*)enemyNode  {
    
    //first apply damage to enemeny
    float enemyHealth = [[enemyNode.userData valueForKey:@"health"] floatValue];
    
    NSLog(@"enemy health: %f",enemyHealth);
    
    enemyHealth -= attackDamage;
    
    NSLog(@"enemy health after damage: %f",enemyHealth);
    
    if (enemyHealth > 0.0) //store new health
    {
        [enemyNode.userData setValue:[NSNumber numberWithFloat:enemyHealth] forKey:@"health"];
    }
    else //only destroy enemy if its health <= 0
    {
        SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
        [enemyNode runAction:asteroidExplosionSound];
        
        
        enemyNode.hidden = YES;
    }

}
- (void) summonanimus
{
    _animusRoot.position = _playerRoot.position;
    _animusRoot.hidden = NO;
    
    //ally moves randomly about and auto-attacks
   
}

- (void) performSpecialAttack
{
    NSLog(@"SPECIAL ATTACK!!!");
    
    //attack damages all enemies onscreen
    for (SKSpriteNode *asteroid in _enemies)
    {
        if (asteroid.hidden)
        {
            continue;
        }
        
        [self applyDamage:4.0 toEnemy:asteroid];
    }
    
    [self updatePlayerSpiritMeterByAmount:-_specialAttackSpiritCost];

    [self disableSpecialAttackState];
}

- (void) updatePlayerSpiritMeterByAmount: (float)difference
{
    float filledPercentage;
    _playerSpiritCount += difference;
    
    if (_playerSpiritCount>_playerSpiritMax)
        filledPercentage = 1.0;
    else
        filledPercentage = _playerSpiritCount/_playerSpiritMax;
    
    //update displayed meter
    [_playerSpiritMeter setSize: CGSizeMake(filledPercentage*self.frame.size.width, 5.0) ];
    
    //with enough spirits, player can perform special attack
    if (_playerSpiritCount>=_specialAttackSpiritCost)
    {
        if (!_playerSpecialAttackIsReady)
            [self enableSpecialAttackState];
    }
}
- (void) updatePlayerHealthMeterByAmount: (float)difference
{
    float filledPercentage;
    _playerHealthCount += difference;
    
    if (_playerHealthCount>_playerHealthMax)
        filledPercentage = 1.0;
    else
        filledPercentage = _playerHealthCount/_playerHealthMax;
    
    //update displayed meter
    [_playerSpiritMeter setSize: CGSizeMake(filledPercentage*self.frame.size.width, 5.0) ];
    //if health 0, game is over
}

- (void) enableSpecialAttackState
{
    //show player state ready for special attack
    SKAction *blink = [SKAction sequence:@[[SKAction fadeOutWithDuration:0.3],
                                           [SKAction fadeInWithDuration:0.3]]];
    SKAction *blinkForever = [SKAction repeatActionForever:blink];
    [_playerSprite runAction:blinkForever withKey:@"specialAttackReady"];
    _playerActivateTouchArea.hidden = NO;
    _playerSpecialAttackIsReady = YES;
}
- (void) disableSpecialAttackState
{
    //cancel specialAttackReady action on player
    [_playerSprite removeActionForKey:@"specialAttackReady"];
    [_playerSprite runAction:[SKAction fadeInWithDuration:0.1]];
    _playerActivateTouchArea.hidden = YES;
    _playerSpecialAttackIsReady = NO;
}

- (void) performBasicAttackWithNode: (SKSpriteNode*)attackNode
{
    //otherwise
    //a single tap anywhere on screen: player performs basic attack
    
    if ([attackNode actionForKey:@"isAttacking"])
        return;
    
    //make a short-range attack
    float attackRadius = 70.0;
    float attackDuration = 0.1;
    
    //preserving its movement relative to player, like a kick or punch
    //not like a free projectile
    CGPoint attackOrigin;
    CGPoint attackEnd;
    
    //NOTE:
    //child node will inherit flipped X-axis from parent node's Xscale
    //so no need to change attach start/end coordinates here if player direction changes
    attackOrigin = CGPointMake(attackNode.size.width,0.0);
    attackEnd = CGPointMake(attackRadius, 0.0);
    
    //NSLog(@"attack start: %f,%f",attackOrigin.x,attackOrigin.y);
    //NSLog(@"attack end: %f,%f",attackEnd.x,attackEnd.y);
    
    attackNode.position = attackOrigin;
    attackNode.hidden = NO;
    [attackNode removeAllActions];
    
    //TODO
    //change player sprite to attack animation
    
    SKAction *laserFireSoundAction = [SKAction playSoundFileNamed:@"laser_ship.caf" waitForCompletion:NO];
    SKAction *laserMoveAction = [SKAction moveTo:attackEnd duration:attackDuration];
    SKAction *laserDoneAction = [SKAction runBlock:(dispatch_block_t)^() {
        //NSLog(@"Animation Completed");
        attackNode.hidden = YES;
    }];
    
    SKAction *moveLaserActionWithDone = [SKAction sequence:@[laserFireSoundAction, laserMoveAction,laserDoneAction]];
    
    [attackNode runAction:moveLaserActionWithDone withKey:@"isAttacking"];
}

#pragma mark - Handle touches
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches) {
        SKNode *n = [self nodeAtPoint:[touch locationInNode:self]];
        
        //check if they touched our Restart Label
        if (n != self && [n.name isEqual: @"restartLabel"]) {
            //[self.theParentView restartScene];
            [[self childNodeWithName:@"restartLabel"] removeFromParent];
            [[self childNodeWithName:@"winLoseLabel"] removeFromParent];
            [self startTheGame];
            return;
        }
        
        //check if touched player
        //perform special attack if ready
        if (n != self && ([n.name isEqual: @"activateTouchArea"] || [n.name isEqual: @"player"]) )
        {
            NSLog(@"touched player");
            if(_playerSpecialAttackIsReady){
                
                //type: damage all enemies onscreen
                [self performSpecialAttack];
                
                //type: freeze all enemies
                //[self freezeAllEnemies];
                
                //type: summon ally
                [self summonanimus];
            }
            return;
        }
    }

    //do not process anymore touches since we are game over
    if (_gameOver) {
        return;
    }
    /*
    SKSpriteNode *shipLaser = [_playerSpriteLasers objectAtIndex:_nextShipLaser];
    _nextShipLaser++;
    if (_nextShipLaser >= _playerSpriteLasers.count) {
        _nextShipLaser = 0;
    }
    */
    [self performBasicAttackWithNode: _playerBasicAttack];

}


// Add new method, above update loop
- (float)randomValueBetween:(float)low andValue:(float)high {
    return (((float) arc4random() / 0xFFFFFFFFu) * (high - low)) + low;
}

-(void) setZPositionFromGlobalYcoordinateRecursivelyForNode:(SKSpriteNode*)parentNode
{
    float zPosition = self.frame.size.height-parentNode.position.y;
    parentNode.zPosition = zPosition;
    for (SKSpriteNode *childNode in parentNode.children) {
        childNode.zPosition = zPosition;
    }
}

-(void) playerTookDamage:(float) damageAmount WithKnockback:(CGPoint) knockbackPosition
{
    _playerHealthCount-=damageAmount;
}

-(void) attack:(SKSpriteNode*) attackNode HitEnemy:(SKSpriteNode*) enemyNode
{
    attackNode.hidden = YES;
    
    float attackDamage = 2.0;
    
    //first apply damage to enemeny
    float enemyHealth = [[enemyNode.userData valueForKey:@"health"] floatValue];
    
    NSLog(@"enemy health: %f",enemyHealth);
    
    enemyHealth -= attackDamage;
    
    NSLog(@"enemy health after damage: %f",enemyHealth);
    
    if (enemyHealth > 0.0) //store new health
    {
        [enemyNode.userData setValue:[NSNumber numberWithFloat:enemyHealth] forKey:@"health"];
    }
    else //only destroy enemy if its health <= 0
    {
        SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
        [enemyNode runAction:asteroidExplosionSound];
        
        enemyNode.hidden = YES;
        
        //spawn powerup where enemy was destroyed
        SKNode *_spiritCollectible;
        _spiritCollectible = [SKSpriteNode spriteNodeWithImageNamed:@"powerup.png"];
        _spiritCollectible.position = enemyNode.position;
        [_spiritCollectible setXScale:0.5];
        [_spiritCollectible setYScale:0.5];
        //_spiritCollectible.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:_spiritCollectible.frame.size];
        //_spiritCollectible.physicsBody.dynamic = YES;
        //_spiritCollectible.physicsBody.affectedByGravity = NO;
        //_spiritCollectible.physicsBody.mass = 0.02;
        [_spiritCollectibles addObject:_spiritCollectible];
        [self addChild:_spiritCollectible];
    }
}
-(void)freezeAllEnemies
{
    for (SKSpriteNode *enemyNode in _enemies)
    {
        [enemyNode removeAllActions];
    }
}

-(void)slowAllEnemiesByPercentage:(float)slowFactor
{
    for (SKSpriteNode *enemyNode in _enemies) {
        
        if ([[enemyNode.userData valueForKey:@"speedState"] isEqualToString:@"slowed"])
            continue;
        
        enemyNode.physicsBody.velocity = CGVectorMake(enemyNode.physicsBody.velocity.dx*slowFactor, enemyNode.physicsBody.velocity.dy*slowFactor);
        [enemyNode.userData setValue:@"slowed" forKey:@"speedState"];
   }
}

-(void)spawnEnemyNode: (SKSpriteNode*)enemyNode atPosition: (CGPoint) startPosition
{
    [enemyNode removeAllActions];

    //give enemy full health
    [enemyNode.userData setValue:[NSNumber numberWithFloat:4.0] forKey:@"health"];
    enemyNode.position = startPosition;
    enemyNode.hidden = NO;
    
    [self moveEnemyNode:enemyNode toPosition:_playerRoot.position];
}
- (void) moveEnemyNode: (SKSpriteNode*)enemyNode toPosition: (CGPoint)location
{
    //if ( (_playerFacingRight && _playerRoot.xScale<0) || (!_playerFacingRight && _playerRoot.xScale>0))
        //_playerRoot.xScale = _playerRoot.xScale*-1.0;
    
    //enemy should face in direction of movement
    if (enemyNode.position.x>location.x)
        enemyNode.xScale = -1.0;
    else
        enemyNode.xScale = 1.0;
    
    float enemyMoveSpeed = 2.0;
    SKAction *moveAction = [SKAction moveTo:location duration:enemyMoveSpeed];
    SKAction *doneAction = [SKAction runBlock:(dispatch_block_t)^(){
        //continue to move enemy toward player
        //[self moveEnemyNode:enemyNode toPosition:_playerRoot.position];
    }];
    
    SKAction *moveEnemyWithDone = [SKAction sequence:@[moveAction,doneAction ]];
    
    [enemyNode runAction:moveEnemyWithDone withKey:@"enemyNodeMoving"];
}

-(void)update:(NSTimeInterval)currentTime
{
    /* Called before each frame is rendered */
    
    //set zPosition based on world Y-coordinate
    //sprites at bottom of screen have higher zPosition than sprites at top
    for (SKSpriteNode *enemyNode in _enemies) {
        [self setZPositionFromGlobalYcoordinateRecursivelyForNode:enemyNode];
        
        //enemy should auto attack when in range of player
        if ([[enemyNode childNodeWithName:@"enemyAttackRange"] intersectsNode:_playerRoot])
        {
            //turn enemy to face player
            //enemy should face in direction of movement
            if (enemyNode.position.x>_playerRoot.position.x)
                enemyNode.xScale = -1.0;
            else
                enemyNode.xScale = 1.0;
            
            //then auto attack!
            [self performBasicAttackWithNode: (SKSpriteNode*)[enemyNode childNodeWithName:@"enemyBasicAttack"]];
        }
    }
    [self setZPositionFromGlobalYcoordinateRecursivelyForNode:_animusRoot];
    [self setZPositionFromGlobalYcoordinateRecursivelyForNode:_playerRoot];
    
    //Update background (parallax) position
    [_parallaxSpaceDust update:currentTime];
    
    [_parallaxNodeBackgrounds update:currentTime];    //other additional game background
    
    //Update ship's position
    [self updateShipPositionFromMotionManager];
    
    //Spawn enemies
    double curTime = CACurrentMediaTime();
    
    if (curTime > _nextAsteroidSpawn)
    {
        //NSLog(@"spawning new asteroid");
        float randSecs = [self randomValueBetween:1.0 andValue:2.0];
        _nextAsteroidSpawn = randSecs + curTime;
        
        float randY = [self randomValueBetween:0.0 andValue:self.frame.size.height];
        
        SKSpriteNode *enemy = [_enemies objectAtIndex:_nextAsteroid];
        _nextAsteroid++;
        
        if (_nextAsteroid >= _enemies.count) {
            _nextAsteroid = 0;
        }
        
        [self spawnEnemyNode: enemy atPosition: CGPointMake(self.frame.size.width+enemy.size.width/2, randY)];
        
    }
    
    //You may be wondering why the asteroids are exploding and still hitting us while in the game over screen!
    //Need to set our update loop to take into account the game is over, as well as keep the background moving!
    //The following if check prevents this from happening
    if (!_gameOver) {
        
        
        //check for laser collision with asteroid
        for (SKSpriteNode *enemy in _enemies) {
            if (enemy.hidden) {
                continue;
            }
            
            SKSpriteNode* enemyAttack = (SKSpriteNode*)[enemy childNodeWithName:@"enemyBasicAttack"];
            //check if enemy attack hit player
            if ([_playerRoot intersectsNode:enemyAttack] && !enemyAttack.hidden)
            {
                
            }
                
            
            if (!_playerBasicAttack.hidden && [_playerBasicAttack intersectsNode:enemy])
                [self attack:_playerBasicAttack HitEnemy:enemy];
            
            /*
            for (SKSpriteNode *shipLaser in _playerSpriteLasers) {
                if (shipLaser.hidden) {
                    continue;
                }
                
                if ([shipLaser intersectsNode:enemy]) {
                    
                    //NSLog(@"you just destroyed an asteroid");
                    continue;
                    
                }
            }
            */
            /*
            if ([_playerSprite intersectsNode:asteroid]) {
                asteroid.hidden = YES;
                SKAction *blink = [SKAction sequence:@[[SKAction fadeOutWithDuration:0.1],
                                                       [SKAction fadeInWithDuration:0.1]]];
                SKAction *blinkForTime = [SKAction repeatAction:blink count:4];
                SKAction *shipExplosionSound = [SKAction playSoundFileNamed:@"explosion_large.caf" waitForCompletion:NO];
                [_playerSprite runAction:[SKAction sequence:@[shipExplosionSound,blinkForTime]]];
                _lives--;
                NSLog(@"your ship has been hit!");
            }
             */
        }
        
        //add to player's spirit total
        for (SKSpriteNode *spiritCollectible in _spiritCollectibles) {
                if ([_playerRoot intersectsNode:spiritCollectible])
                {
                    if (spiritCollectible.hidden) {
                        continue;
                    }
                    
                    spiritCollectible.hidden = YES;
                    [self updatePlayerSpiritMeterByAmount: 10.0];
                    NSLog(@"spirits collected: %f",_playerSpiritCount);
                    
                }
        }
        
        // handle whether we are game over
        if (_lives <= 0) {
            NSLog(@"you lose...");
            [self endTheScene:kEndReasonLose];
        } else if (curTime >= _gameOverTime) {
            NSLog(@"you won...");
            [self endTheScene:kEndReasonWin];
        }
    }
    
}



- (void)endTheScene:(EndReason)endReason {
    if (_gameOver) {
        return;
    }
    
    [self removeAllActions];
    [self stopMonitoringAcceleration];
    _playerSprite.hidden = YES;
    _gameOver = YES;
    
    NSString *message;
    if (endReason == kEndReasonWin) {
        message = @"You win!";
    } else if (endReason == kEndReasonLose) {
        message = @"You lost!";
    }
    
    SKLabelNode *label;
    label = [[SKLabelNode alloc] initWithFontNamed:@"Futura-CondensedMedium"];
    label.name = @"winLoseLabel";
    label.text = message;
    label.scale = 0.1;
    label.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.6);
    label.fontColor = [SKColor yellowColor];
    [self addChild:label];
    
    SKLabelNode *restartLabel;
    restartLabel = [[SKLabelNode alloc] initWithFontNamed:@"Futura-CondensedMedium"];
    restartLabel.name = @"restartLabel";
    restartLabel.text = @"Play Again?";
    restartLabel.scale = 0.5;
    restartLabel.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.4);
    restartLabel.fontColor = [SKColor yellowColor];
    [self addChild:restartLabel];
    
    SKAction *labelScaleAction = [SKAction scaleTo:1.0 duration:0.5];
    
    [restartLabel runAction:labelScaleAction];
    [label runAction:labelScaleAction];
    
}

@end